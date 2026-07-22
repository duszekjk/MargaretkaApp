import Foundation
internal import zlib

enum BrewiarzEPUBImportError: LocalizedError {
    case invalidArchive
    case unsupportedCompression(UInt16)
    case damagedEntry(String)
    case noBreviaryDocuments
    case noOffices

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "Plik nie jest prawidłowym archiwum EPUB."
        case .unsupportedCompression(let method):
            return "EPUB używa nieobsługiwanej metody kompresji ZIP (\(method))."
        case .damagedEntry(let name):
            return "Nie udało się odczytać elementu EPUB: \(name)"
        case .noBreviaryDocuments:
            return "W EPUB nie znaleziono dziennych plików brewiarza.pl."
        case .noOffices:
            return "W EPUB nie znaleziono Liturgii Godzin."
        }
    }
}

struct BrewiarzEPUBImportResult {
    var days: [OfflineBreviaryDay]
    var sourceTitle: String
    var skippedDocumentCount: Int
}

struct BrewiarzEPUBImportProgress: Equatable, Sendable {
    var completedDocuments: Int
    var totalDocuments: Int
    var elapsed: TimeInterval

    var fractionCompleted: Double {
        guard totalDocuments > 0 else { return 0 }
        return min(1, Double(completedDocuments) / Double(totalDocuments))
    }

    var estimatedRemaining: TimeInterval? {
        guard completedDocuments > 0, completedDocuments < totalDocuments else {
            return completedDocuments == totalDocuments ? 0 : nil
        }
        return elapsed / Double(completedDocuments) * Double(totalDocuments - completedDocuments)
    }
}

nonisolated enum BrewiarzEPUBImporter {
    private static let officeAnchors: [(anchor: String, key: BrewiarzPrayerKey)] = [
        ("wezw", .wezwanie),
        ("gc", .godzinaCzytan),
        ("jt", .jutrznia),
        ("m1", .modlitwaPrzedpoludniowa),
        ("m2", .modlitwaPoludniowa),
        ("m3", .modlitwaPopoludniowa),
        ("n", .nieszpory),
        ("k", .kompleta)
    ]

    nonisolated static func importEPUB(
        from url: URL,
        preferredVariantOrder: [String]? = nil,
        progress: (@MainActor @Sendable (BrewiarzEPUBImportProgress) -> Void)? = nil
    ) async throws -> BrewiarzEPUBImportResult {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let archive = try SimpleZIPArchive(data: Data(contentsOf: url))
        let allCandidates = archive.entryNames.filter(isDailyBreviaryDocument)
        guard !allCandidates.isEmpty else { throw BrewiarzEPUBImportError.noBreviaryDocuments }
        let candidates = preferredVariantOrder.map {
            selectedDailyDocuments(from: allCandidates, preferenceOrder: $0)
        } ?? allCandidates

        let startedAt = Date()
        if let progress {
            await progress(BrewiarzEPUBImportProgress(
                completedDocuments: 0,
                totalDocuments: candidates.count,
                elapsed: 0
            ))
        }
        let importID = UUID()
        let sortedCandidates = candidates.sorted()
        let sourceIdentifier = url.lastPathComponent
        let sourceTitle = url.deletingPathExtension().lastPathComponent
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        let concurrentDocumentLimit = min(4, max(2, processorCount - 1), sortedCandidates.count)
        var parsedDays = Array<OfflineBreviaryDay?>(repeating: nil, count: sortedCandidates.count)
        var completedDocuments = 0

        await withTaskGroup(of: (Int, OfflineBreviaryDay?).self) { group in
            var nextCandidateIndex = 0

            func enqueueCandidate(at index: Int) {
                let name = sortedCandidates[index]
                group.addTask {
                    guard let data = try? archive.data(for: name),
                          let xhtml = String(data: data, encoding: .utf8) else {
                        return (index, nil)
                    }
                    return (
                        index,
                        parseDailyDocument(
                            xhtml,
                            entryName: name,
                            importID: importID,
                            sourceIdentifier: sourceIdentifier,
                            sourceTitle: sourceTitle
                        )
                    )
                }
            }

            while nextCandidateIndex < concurrentDocumentLimit {
                enqueueCandidate(at: nextCandidateIndex)
                nextCandidateIndex += 1
            }

            while let (index, day) = await group.next() {
                parsedDays[index] = day
                completedDocuments += 1
                if let progress {
                    await progress(BrewiarzEPUBImportProgress(
                        completedDocuments: completedDocuments,
                        totalDocuments: sortedCandidates.count,
                        elapsed: Date().timeIntervalSince(startedAt)
                    ))
                }
                if nextCandidateIndex < sortedCandidates.count {
                    enqueueCandidate(at: nextCandidateIndex)
                    nextCandidateIndex += 1
                }
            }
        }
        let days = parsedDays.compactMap { $0 }
        let skipped = sortedCandidates.count - days.count
        guard !days.isEmpty else { throw BrewiarzEPUBImportError.noOffices }
        return BrewiarzEPUBImportResult(
            days: days,
            sourceTitle: url.deletingPathExtension().lastPathComponent,
            skippedDocumentCount: skipped
        )
    }

    static func parseDailyDocument(
        _ xhtml: String,
        entryName: String,
        importID: UUID,
        sourceIdentifier: String,
        sourceTitle: String
    ) -> OfflineBreviaryDay? {
        let documentLines = XHTMLPrayerLineParser.parse(xhtml)
        let documentText = documentLines.map(\.text).joined(separator: "\n")
        guard let date = parseCivilDate(documentText) else { return nil }
        let celebration = parseCelebration(documentText)
        let liturgicalColor = parseLiturgicalColor(documentText)
        let saintBiography = parseSaintBiography(documentLines, celebration: celebration)
        let variantIdentifier = parseVariantIdentifier(entryName)
        let anchorNamespace = dailyAnchorNamespace(entryName)
        var offices: [OfflineBreviaryOffice] = []

        for (index, definition) in officeAnchors.enumerated() {
            guard let section = section(
                in: xhtml,
                startingAt: definition.anchor,
                endingAt: Array(officeAnchors.dropFirst(index + 1).map(\.anchor)),
                anchorNamespace: anchorNamespace
            ) else { continue }
            let parsedLines = XHTMLPrayerLineParser.parse(section)
            let meaningful = discardNavigationAndMetadata(parsedLines, officeTitle: definition.key.displayName)
            guard !meaningful.isEmpty else { continue }
            let cards = paginate(meaningful)
            offices.append(
                OfflineBreviaryOffice(
                    key: definition.key,
                    cards: cards,
                    contentFingerprint: stableFingerprint(meaningful),
                    imagePrompt: promptSeed(
                        office: definition.key,
                        date: date,
                        celebration: celebration,
                        liturgicalColor: liturgicalColor,
                        lines: meaningful
                    ),
                    imageSourceText: imageSourceText(
                        celebration: celebration,
                        liturgicalColor: liturgicalColor,
                        lines: meaningful
                    )
                )
            )
        }
        guard !offices.isEmpty else { return nil }
        return OfflineBreviaryDay(
            date: date,
            variantIdentifier: variantIdentifier,
            variantName: variantName(identifier: variantIdentifier, xhtml: xhtml),
            celebrationName: celebration,
            liturgicalColor: liturgicalColor,
            saintBiography: saintBiography,
            offices: offices,
            sourceImportID: importID,
            sourceIdentifier: sourceIdentifier,
            sourceTitle: sourceTitle
        )
    }

    static func isDailyBreviaryDocument(_ name: String) -> Bool {
        let filename = URL(fileURLWithPath: name).lastPathComponent.lowercased()
        guard filename.hasSuffix(".xhtml") else { return false }
        let stem = String(filename.dropLast(6))
        guard stem.count >= 4 else { return false }
        return stem.prefix(4).allSatisfy(\.isNumber)
            && stem.dropFirst(4).allSatisfy { $0.isLetter || $0.isNumber }
    }

    static func selectedDailyDocuments(from names: [String], preferenceOrder: [String]) -> [String] {
        let daily = names.filter(isDailyBreviaryDocument)
        let grouped = Dictionary(grouping: daily) { name in
            let stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent.lowercased()
            return String(stem.prefix(4))
        }
        let order = BreviaryVariantPreferences.normalizedOrder(
            preferenceOrder,
            including: daily.map(parseVariantIdentifier)
        )
        return grouped.keys.sorted().compactMap { dateKey in
            let documents = grouped[dateKey, default: []].sorted()
            for identifier in order {
                if let document = documents.first(where: { parseVariantIdentifier($0) == identifier }) {
                    return document
                }
            }
            return documents.first
        }
    }

    private static func parseVariantIdentifier(_ entryName: String) -> String {
        let stem = URL(fileURLWithPath: entryName).deletingPathExtension().lastPathComponent.lowercased()
        let identifier = String(stem.dropFirst(min(4, stem.count)))
        return identifier.isEmpty ? "p" : identifier
    }

    private static func dailyAnchorNamespace(_ entryName: String) -> String {
        let stem = URL(fileURLWithPath: entryName).deletingPathExtension().lastPathComponent.lowercased()
        return "d\(stem)_"
    }

    private static func variantName(identifier: String, xhtml: String) -> String {
        let prefix = xhtml.range(of: "U paulinów", options: [.caseInsensitive, .diacriticInsensitive]) != nil
            ? "U paulinów"
            : nil
        switch identifier {
        case "p": return prefix ?? "Tekst podstawowy"
        case "w": return prefix ?? "Wspomnienie"
        default: return prefix ?? "Wariant \(identifier.uppercased())"
        }
    }

    private static func parseCivilDate(_ plain: String) -> BreviaryCivilDate? {
        let pattern = #"(?i)(\d{1,2})\s+(stycznia|lutego|marca|kwietnia|maja|czerwca|lipca|sierpnia|września|wrzesnia|października|pazdziernika|listopada|grudnia)\s+(\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: plain, range: NSRange(plain.startIndex..., in: plain)),
              let dayRange = Range(match.range(at: 1), in: plain),
              let monthRange = Range(match.range(at: 2), in: plain),
              let yearRange = Range(match.range(at: 3), in: plain),
              let day = Int(plain[dayRange]),
              let year = Int(plain[yearRange]) else { return nil }
        let monthName = String(plain[monthRange]).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        let months = [
            "stycznia": 1, "lutego": 2, "marca": 3, "kwietnia": 4,
            "maja": 5, "czerwca": 6, "lipca": 7, "sierpnia": 8,
            "wrzesnia": 9, "pazdziernika": 10, "listopada": 11, "grudnia": 12
        ]
        guard let month = months[monthName] else { return nil }
        return BreviaryCivilDate(year: year, month: month, day: day)
    }

    private static func parseLiturgicalColor(_ plain: String) -> String? {
        firstCapture(in: plain, pattern: #"(?i)Kolor\s+szat:\s*([^\n]+)"#)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseCelebration(_ plain: String) -> String? {
        let lines = plain
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let dateIndex = lines.firstIndex(where: { $0.range(of: #"\d{1,2}\s+\p{L}+\s+\d{4}"#, options: .regularExpression) != nil }) else {
            return nil
        }
        let exclusions = [
            "tydzień", "kolor szat", "wspomnienie obowiązkowe", "wspomnienie dowolne",
            "kartka z kalendarza", "inne oficja", "wykaz obchodów", "teksty mszy"
        ]
        return lines.dropFirst(dateIndex + 1).prefix(5).first { line in
            let lower = line.lowercased()
            return exclusions.allSatisfy { !lower.contains($0) }
                && line.rangeOfCharacter(from: .letters) != nil
                && line.count < 120
        }
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func parseSaintBiography(
        _ lines: [OfflineBreviaryLine],
        celebration: String?
    ) -> OfflineSaintBiography? {
        guard let markerIndex = lines.firstIndex(where: {
            normalizedForComparison($0.text).hasPrefix("garsc informacji:")
        }) else { return nil }

        let stopPhrases = [
            "teksty mszy", "propozycja spiewow", "wezwanie", "godzina czytan",
            "jutrznia", "modlitwa przedpoludniowa", "modlitwa poludniowa",
            "modlitwa popoludniowa", "nieszpory", "kompleta"
        ]
        var biographyLines: [OfflineBreviaryLine] = []
        for line in lines.dropFirst(markerIndex + 1) {
            let normalized = normalizedForComparison(line.text)
            if stopPhrases.contains(where: normalized.hasPrefix) { break }
            guard line.role != .rubric,
                  !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            biographyLines.append(
                OfflineBreviaryLine(
                    role: .body,
                    text: line.text,
                    emphasized: false,
                    italic: false
                )
            )
        }

        guard biographyLines.contains(where: { $0.text.count >= 80 }) else { return nil }
        let trimmedCelebration = celebration?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedCelebration?.isEmpty == false ? trimmedCelebration! : "Święty dnia"
        return OfflineSaintBiography(
            title: title,
            cards: paginate(biographyLines, initialTitle: title)
        )
    }

    private static func normalizedForComparison(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func section(
        in xhtml: String,
        startingAt anchor: String,
        endingAt laterAnchors: [String],
        anchorNamespace: String
    ) -> String? {
        let startPatterns = anchorPatterns(for: anchor, namespace: anchorNamespace)
        guard let start = startPatterns.compactMap({ xhtml.range(of: $0, options: .caseInsensitive)?.lowerBound }).min() else {
            return nil
        }
        let tail = xhtml[start...]
        let end = laterAnchors.flatMap { next in
            anchorPatterns(for: next, namespace: anchorNamespace)
        }.compactMap { tail.range(of: $0, options: .caseInsensitive)?.lowerBound }.min() ?? xhtml.endIndex
        return String(xhtml[start..<end])
    }

    private static func anchorPatterns(for anchor: String, namespace: String) -> [String] {
        [namespace + anchor, anchor].flatMap { candidate in
            [
                "<a id=\"\(candidate)\"",
                "<a name=\"\(candidate)\"",
                "<a id='\(candidate)'",
                "<a name='\(candidate)'"
            ]
        }
    }

    private static func discardNavigationAndMetadata(
        _ lines: [OfflineBreviaryLine],
        officeTitle: String
    ) -> [OfflineBreviaryLine] {
        let navigationPhrases = [
            "kartka z kalendarza", "inne oficja", "wykaz obchodów", "teksty mszy",
            "wczoraj", "dzisiaj", "copyright by", "opracowanie i edycja", "Na końcu tej pieśni nie mówi się Chwała Ojcu."
        ]
        let normalizedOfficeTitle = officeTitle.lowercased()
        let otherOfficeTitles = Set(
            BrewiarzPrayerKey.allCases
                .map { $0.displayName.lowercased() }
                .filter { $0 != normalizedOfficeTitle }
        )
        var didFindOfficeTitle = !lines.contains { $0.text.lowercased() == normalizedOfficeTitle }
        var discardingCanonicalPrayer = false
        var discardingPsalmComment = false
        var result: [OfflineBreviaryLine] = []
        for var line in lines {
            let lower = line.text.lowercased()
            if navigationPhrases.contains(where: lower.contains) { continue }
            if line.role == .rubric
                || lower.hasPrefix("excerpt from")
                || lower == "brewiarz.pl" {
                continue
            }
            if otherOfficeTitles.contains(lower) { continue }
            if lower.hasPrefix("kolor szat:")
                || lower.range(of: #"\d{1,2}\s+\p{L}+\s+\d{4}"#, options: .regularExpression) != nil {
                continue
            }
            let folded = lower.folding(
                options: [.diacriticInsensitive],
                locale: Locale(identifier: "pl_PL")
            )
            if line.role == .heading && folded.hasPrefix("psalmodia") { continue }
            if line.role == .heading {
                if isPsalmOrCanticleHeading(line.text) {
                    discardingPsalmComment = true
                } else if discardingPsalmComment && isSemanticSectionHeading(line.text) {
                    discardingPsalmComment = false
                }
            } else if discardingPsalmComment {
                if line.italic { continue }
                discardingPsalmComment = false
            }
            if discardingCanonicalPrayer {
                if line.role == .heading {
                    discardingCanonicalPrayer = false
                } else {
                    if lower.contains("ale nas zbaw ode złego") {
                        discardingCanonicalPrayer = false
                    }
                    continue
                }
            }
            if !didFindOfficeTitle {
                guard lower == normalizedOfficeTitle else { continue }
                didFindOfficeTitle = true
                line.role = .heading
                result.append(line)
                continue
            }
            if lower == "ojcze nasz..." || lower == "ojcze nasz…" || lower.hasPrefix("ojcze nasz,") {
                line.role = .prayerReference
                line.canonicalPrayerName = "Ojcze nasz"
                line.text = "Ojcze nasz"
                discardingCanonicalPrayer = lower.hasPrefix("ojcze nasz,")
            }
            result.append(line)
        }
        while result.first?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.removeFirst()
        }
        return result
    }

    private static func isPsalmOrCanticleHeading(_ text: String) -> Bool {
        text.range(
            of: #"(?i)^(psalm|pieśń|kantyk)(\s|$)"#,
            options: [.regularExpression, .diacriticInsensitive]
        ) != nil
    }

    private static func isSemanticSectionHeading(_ text: String) -> Bool {
        text.range(
            of: #"(?i)^(psalm|pieśń|kantyk|hymn|czytanie|responsorium|prośby|modlitwa|te deum)(\s|$)"#,
            options: [.regularExpression, .diacriticInsensitive]
        ) != nil
    }

    private static func paginate(
        _ lines: [OfflineBreviaryLine],
        initialTitle: String? = nil
    ) -> [OfflineBreviaryCard] {
        let maxCharacters = 410
        let maxLines = 9
        var cards: [OfflineBreviaryCard] = []
        var current: [OfflineBreviaryLine] = []
        var characterCount = 0
        var sectionTitle = initialTitle
        var awaitingNumberedAntiphonTitle = false

        func flush() {
            guard !current.isEmpty else { return }
            cards.append(OfflineBreviaryCard(title: sectionTitle, lines: current))
            current = []
            characterCount = 0
        }

        for line in lines.flatMap({ splitForPagination($0, maximumCharacters: maxCharacters) }) {
            if line.role == .prayerReference {
                flush()
                cards.append(OfflineBreviaryCard(title: line.canonicalPrayerName, lines: [line]))
                sectionTitle = nil
                awaitingNumberedAntiphonTitle = false
                continue
            }
            let numberedAntiphon = isNumberedAntiphon(line.text)
            if numberedAntiphon {
                flush()
                sectionTitle = nil
                awaitingNumberedAntiphonTitle = true
            }
            if line.role == .heading {
                if awaitingNumberedAntiphonTitle {
                    sectionTitle = line.text
                    awaitingNumberedAntiphonTitle = false
                } else {
                    flush()
                    sectionTitle = line.text
                }
            }
            let wouldOverflow = !current.isEmpty
                && (characterCount + line.text.count > maxCharacters || current.count >= maxLines)
            if wouldOverflow { flush() }
            current.append(line)
            characterCount += line.text.count
        }
        flush()
        return numberedContinuationTitles(in: cards)
    }

    private static func isNumberedAntiphon(_ text: String) -> Bool {
        text.range(
            of: #"^\s*\d+\s+ant\."#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil || text.range(
            of: #"^\s*[147]\s+"#,
            options: .regularExpression
        ) != nil || text.range(
            of: #"^\s*Psalm\s+\d+\,"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil || text.range(
            of: #"^\s*Pieśń\s+\("#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func numberedContinuationTitles(
        in cards: [OfflineBreviaryCard]
    ) -> [OfflineBreviaryCard] {
        let totals = Dictionary(grouping: cards.compactMap(\.title), by: { $0 })
            .mapValues(\.count)
        var occurrences: [String: Int] = [:]
        return cards.map { card in
            guard let title = card.title, totals[title, default: 0] > 1 else { return card }
            occurrences[title, default: 0] += 1
            var numbered = card
            numbered.title = "\(title) (\(occurrences[title, default: 1])/\(totals[title, default: 1]))"
            return numbered
        }
    }

    private static func splitForPagination(
        _ line: OfflineBreviaryLine,
        maximumCharacters: Int
    ) -> [OfflineBreviaryLine] {
        guard line.role != .heading,
              line.role != .prayerReference,
              line.text.count > maximumCharacters else { return [line] }

        var chunks: [String] = []
        var current = ""
        for word in line.text.split(whereSeparator: { $0.isWhitespace }) {
            let candidate = current.isEmpty ? String(word) : "\(current) \(word)"
            if candidate.count <= maximumCharacters {
                current = candidate
            } else {
                if !current.isEmpty { chunks.append(current) }
                current = String(word)
            }
        }
        if !current.isEmpty { chunks.append(current) }

        return chunks.map {
            OfflineBreviaryLine(
                role: line.role,
                text: $0,
                canonicalPrayerName: line.canonicalPrayerName,
                emphasized: line.emphasized,
                italic: line.italic
            )
        }
    }

    private static func stableFingerprint(_ lines: [OfflineBreviaryLine]) -> String {
        let source = lines.map { "\($0.role.rawValue)|\($0.text)" }.joined(separator: "\n")
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func promptSeed(
        office: BrewiarzPrayerKey,
        date: BreviaryCivilDate,
        celebration: String?,
        liturgicalColor: String?,
        lines: [OfflineBreviaryLine]
    ) -> String {
        let englishOffice: String
        switch office {
        case .wezwanie: englishOffice = "Invitatory"
        case .godzinaCzytan: englishOffice = "Office of Readings"
        case .jutrznia: englishOffice = "Morning Prayer"
        case .modlitwaPrzedpoludniowa: englishOffice = "Midmorning Prayer"
        case .modlitwaPoludniowa: englishOffice = "Midday Prayer"
        case .modlitwaPopoludniowa: englishOffice = "Midafternoon Prayer"
        case .nieszpory: englishOffice = "Evening Prayer"
        case .kompleta: englishOffice = "Night Prayer"
        }
        let excerpts = lines
            .filter { [.antiphon, .body].contains($0.role) && $0.text.count > 35 }
            .prefix(3)
            .map { "“\($0.text.prefix(220))”" }
            .joined(separator: "\n")
        return """
        Create a calm, reverent background image for the Catholic Liturgy of the Hours.
        Office: \(office.displayName) (\(englishOffice)). Date: \(date.id).
        Celebration in Polish: \(celebration ?? "none specified").
        Liturgical color: \(liturgicalColor ?? "not specified").
        Use the prayer themes below as visual inspiration. Do not put words or letters in the image:
        \(excerpts)
        """
    }

    private static func imageSourceText(
        celebration: String?,
        liturgicalColor: String?,
        lines: [OfflineBreviaryLine]
    ) -> String {
        let excerpts = lines
            .filter { [.antiphon, .body].contains($0.role) && $0.text.count > 35 }
            .prefix(3)
            .map(\.text)
            .joined(separator: "\n")
        return """
        Święto: \(celebration ?? "brak określonego święta")
        Kolor szat: \(liturgicalColor ?? "nieokreślony")
        \(excerpts)
        """
    }
}

nonisolated private final class XHTMLPrayerLineParser: NSObject, XMLParserDelegate {
    private struct Style {
        var emphasized = false
        var italic = false
        var rubric = false
        var leftAligned = false
        var navigationLink = false
    }

    private var styleStack: [Style] = [Style()]
    private var bufferStyle = Style()
    private var buffer = ""
    private var bufferHasRubricText = false
    private var bufferHasPrayerText = false
    private var lines: [OfflineBreviaryLine] = []

    static func parse(_ xhtml: String) -> [OfflineBreviaryLine] {
        let sanitized = sanitize(xhtml)
        guard let data = sanitized.data(using: .utf8) else { return [] }
        let delegate = XHTMLPrayerLineParser()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        _ = parser.parse()
        delegate.flush()
        return delegate.lines
    }

    static func plainText(_ xhtml: String) -> String {
        parse(xhtml).map(\.text).joined(separator: "\n")
    }

    private static func sanitize(_ xhtml: String) -> String {
        var value = xhtml.replacingOccurrences(of: "&nbsp;", with: "\u{00A0}")
        if let doctypeStart = value.range(of: "<!DOCTYPE", options: .caseInsensitive),
           let doctypeEnd = value[doctypeStart.lowerBound...].range(of: ">") {
            value.removeSubrange(doctypeStart.lowerBound...doctypeEnd.lowerBound)
        }
        if value.range(of: "<html", options: .caseInsensitive) == nil {
            value = "<root>\(value)</root>"
        }
        return value
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        if name == "br" { flush() }
        var style = styleStack.last ?? Style()
        if name == "b" || name == "strong" { style.emphasized = true }
        if name == "i" || name == "em" { style.italic = true }
        if name == "a", attributeDict["href"] != nil { style.navigationLink = true }
        let inlineStyle = attributeDict["style"]?.lowercased() ?? ""
        if inlineStyle.contains("font-weight:bold") || inlineStyle.contains("font-weight: bold") {
            style.emphasized = true
        }
        if inlineStyle.contains("font-style:italic") || inlineStyle.contains("font-style: italic") {
            style.italic = true
        }
        if inlineStyle.contains("color:red") || inlineStyle.contains("color: red") {
            style.rubric = true
        }
        if inlineStyle.contains("text-align:left") || inlineStyle.contains("text-align: left") {
            style.leftAligned = true
        } else if inlineStyle.contains("text-align:center")
                    || inlineStyle.contains("text-align: center")
                    || inlineStyle.contains("text-align:right")
                    || inlineStyle.contains("text-align: right")
                    || inlineStyle.contains("text-align:justify")
                    || inlineStyle.contains("text-align: justify") {
            style.leftAligned = false
        }
        styleStack.append(style)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
        guard string.rangeOfCharacter(from: .whitespacesAndNewlines.inverted) != nil else { return }
        let style = styleStack.last ?? Style()
        if style.rubric {
            bufferHasRubricText = true
        } else {
            bufferHasPrayerText = true
        }
        bufferStyle.emphasized = bufferStyle.emphasized || style.emphasized
        bufferStyle.italic = bufferStyle.italic || style.italic
        bufferStyle.rubric = bufferStyle.rubric || style.rubric
        bufferStyle.leftAligned = bufferStyle.leftAligned || style.leftAligned
        bufferStyle.navigationLink = bufferStyle.navigationLink || style.navigationLink
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        if ["div", "p", "li", "h1", "h2", "h3", "h4"].contains(name) { flush() }
        if styleStack.count > 1 { styleStack.removeLast() }
    }

    fileprivate func flush() {
        let raw = buffer.replacingOccurrences(of: "\r", with: "")
        buffer = ""
        let style = bufferStyle
        let isRubricOnly = bufferHasRubricText && !bufferHasPrayerText
        bufferStyle = Style()
        bufferHasRubricText = false
        bufferHasPrayerText = false
        guard !style.navigationLink else { return }
        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let leadingChoirIndent = rawLine.prefix { $0 == "\u{00A0}" || $0 == " " }.count >= 4
            let text = rawLine
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let isUppercaseHeading = style.emphasized
                && text.count < 100
                && text == text.uppercased()
                && text.rangeOfCharacter(from: .letters) != nil
            let role: OfflineBreviaryLineRole
            if folded.hasPrefix("k.") { role = .leader }
            else if folded.hasPrefix("w.") { role = .response }
            else if folded.hasPrefix("ant.") || Self.isNumberedAntiphon(text) { role = .antiphon }
            else if leadingChoirIndent { role = .choirRight }
            else if isUppercaseHeading || Self.isSemanticPrayerHeading(text) { role = .heading }
            else if isRubricOnly { role = .rubric }
            else if style.leftAligned { role = .choirLeft }
            else if style.emphasized && text.count < 100 { role = .heading }
            else { role = .body }
            lines.append(
                OfflineBreviaryLine(
                    role: role,
                    text: text,
                    emphasized: style.emphasized,
                    italic: style.italic
                )
            )
        }
    }

    private static func isSemanticPrayerHeading(_ text: String) -> Bool {
        text.range(
            of: #"(?i)^(psalm|pieśń|kantyk|hymn|czytanie|responsorium|prośby|modlitwa|te deum)(\s|$)"#,
            options: [.regularExpression, .diacriticInsensitive]
        ) != nil
    }

    private static func isNumberedAntiphon(_ text: String) -> Bool {
        text.range(
            of: #"^\s*\d+\s+ant\."#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}

nonisolated private struct SimpleZIPArchive: Sendable {
    private struct Entry: Sendable {
        var name: String
        var compressionMethod: UInt16
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
    }

    private let archiveData: Data
    private let entries: [String: Entry]

    var entryNames: [String] { Array(entries.keys) }

    init(data: Data) throws {
        archiveData = data
        entries = try Self.readDirectory(data)
    }

    func data(for name: String) throws -> Data {
        guard let entry = entries[name] else { throw BrewiarzEPUBImportError.damagedEntry(name) }
        let offset = entry.localHeaderOffset
        guard archiveData.uint32LE(at: offset) == 0x04034b50 else {
            throw BrewiarzEPUBImportError.damagedEntry(name)
        }
        let filenameLength = Int(archiveData.uint16LE(at: offset + 26))
        let extraLength = Int(archiveData.uint16LE(at: offset + 28))
        let start = offset + 30 + filenameLength + extraLength
        let end = start + entry.compressedSize
        guard start >= 0, end <= archiveData.count else {
            throw BrewiarzEPUBImportError.damagedEntry(name)
        }
        let compressed = archiveData.subdata(in: start..<end)
        switch entry.compressionMethod {
        case 0:
            return compressed
        case 8:
            return try Self.inflateRaw(compressed, expectedSize: entry.uncompressedSize, name: name)
        default:
            throw BrewiarzEPUBImportError.unsupportedCompression(entry.compressionMethod)
        }
    }

    private static func readDirectory(_ data: Data) throws -> [String: Entry] {
        guard let endOffset = data.lastOffset(of: 0x06054b50, searchWindow: 65_557) else {
            throw BrewiarzEPUBImportError.invalidArchive
        }
        let count = Int(data.uint16LE(at: endOffset + 10))
        var cursor = Int(data.uint32LE(at: endOffset + 16))
        var result: [String: Entry] = [:]
        for _ in 0..<count {
            guard data.uint32LE(at: cursor) == 0x02014b50 else {
                throw BrewiarzEPUBImportError.invalidArchive
            }
            let method = data.uint16LE(at: cursor + 10)
            let compressedSize = Int(data.uint32LE(at: cursor + 20))
            let uncompressedSize = Int(data.uint32LE(at: cursor + 24))
            let filenameLength = Int(data.uint16LE(at: cursor + 28))
            let extraLength = Int(data.uint16LE(at: cursor + 30))
            let commentLength = Int(data.uint16LE(at: cursor + 32))
            let localOffset = Int(data.uint32LE(at: cursor + 42))
            let nameStart = cursor + 46
            let nameEnd = nameStart + filenameLength
            guard nameEnd <= data.count,
                  let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) else {
                throw BrewiarzEPUBImportError.invalidArchive
            }
            result[name] = Entry(
                name: name,
                compressionMethod: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localOffset
            )
            cursor = nameEnd + extraLength + commentLength
        }
        return result
    }

    private static func inflateRaw(_ data: Data, expectedSize: Int, name: String) throws -> Data {
        var output = Data(count: max(1, expectedSize))
        let outputCapacity = output.count
        var stream = z_stream()
        let initialized = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initialized == Z_OK else { throw BrewiarzEPUBImportError.damagedEntry(name) }
        defer { inflateEnd(&stream) }

        let status: Int32 = data.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(data.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(outputCapacity)
                return inflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END else { throw BrewiarzEPUBImportError.damagedEntry(name) }
        output.count = Int(stream.total_out)
        return output
    }
}

private extension Data {
    nonisolated func uint16LE(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        return withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        }
    }

    nonisolated func uint32LE(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        return withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            return UInt32(bytes[offset])
                | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16)
                | (UInt32(bytes[offset + 3]) << 24)
        }
    }

    nonisolated func lastOffset(of signature: UInt32, searchWindow: Int) -> Int? {
        guard count >= 4 else { return nil }
        let lowerBound = Swift.max(0, count - searchWindow)
        var offset = count - 4
        while offset >= lowerBound {
            if uint32LE(at: offset) == signature { return offset }
            offset -= 1
        }
        return nil
    }
}
