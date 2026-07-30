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
        ("czyt", .msza),
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
        maximumVariantsPerDay: Int = 1,
        progress: (@MainActor @Sendable (BrewiarzEPUBImportProgress) -> Void)? = nil
    ) async throws -> BrewiarzEPUBImportResult {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let archive = try SimpleZIPArchive(data: Data(contentsOf: url))
        if archive.entryNames.contains(where: { $0.hasSuffix("contents.xhtml") }),
           let contentsData = try? archive.data(for: archive.entryNames.first(where: { $0.hasSuffix("contents.xhtml") })!),
           let contents = String(data: contentsData, encoding: .utf8),
           contents.contains("universalis.css") {
            return try await importUniversalisEPUB(from: archive, sourceURL: url, contents: contents, progress: progress)
        }
        let allCandidates = archive.entryNames.filter(isDailyBreviaryDocument)
        guard !allCandidates.isEmpty else { throw BrewiarzEPUBImportError.noBreviaryDocuments }
        let candidates = preferredVariantOrder.map {
            selectedDailyDocuments(
                from: allCandidates,
                preferenceOrder: $0,
                maximumVariantsPerDay: maximumVariantsPerDay,
                documentText: { name in
                    guard let data = try? archive.data(for: name) else { return nil }
                    return String(data: data, encoding: .utf8)
                }
            )
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

    private static func importUniversalisEPUB(
        from archive: SimpleZIPArchive,
        sourceURL: URL,
        contents: String,
        progress: (@MainActor @Sendable (BrewiarzEPUBImportProgress) -> Void)?
    ) async throws -> BrewiarzEPUBImportResult {
        let languageCode = contents.contains("Index dierum") ? "la" : "en"
        let links = captures(in: contents, pattern: #"href=\"([^\"]*u\d+\.xhtml)\"[^>]*>([^<]+)<"#)
        let importID = UUID()
        let sourceTitle = sourceURL.deletingPathExtension().lastPathComponent
        var days: [OfflineBreviaryDay] = []
        for (index, link) in links.enumerated() where link.count == 2 {
            guard let date = universalisDate(link[1]) else { continue }
            guard let base = universalisEntryName(for: link[0], in: archive) else { continue }
            guard let data = try? archive.data(for: base), let dayPage = String(data: data, encoding: .utf8) else { continue }
            var offices: [OfflineBreviaryOffice] = []
            for officeLink in captures(in: dayPage, pattern: #"href=\"([^\"]+\.xhtml)\"[^>]*>([^<]+)<"#) where officeLink.count == 2 {
                guard let key = universalisOfficeKey(officeLink[1]),
                      let officeEntry = universalisEntryName(for: officeLink[0], in: archive),
                      let officeData = try? archive.data(for: officeEntry),
                      let officePage = String(data: officeData, encoding: .utf8) else { continue }
                let parsedLines = XHTMLPrayerLineParser.parse(officePage)
                let filteredLines = discardNavigationAndMetadata(parsedLines, officeTitle: officeLink[1])
                let lines = filteredLines.isEmpty ? parsedLines.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } : filteredLines
                guard !lines.isEmpty else { continue }
                offices.append(OfflineBreviaryOffice(key: key, title: officeLink[1], cards: paginate(lines), contentFingerprint: stableFingerprint(lines)))
            }
            if !offices.isEmpty {
                days.append(OfflineBreviaryDay(
                    date: date,
                    variantIdentifier: "p",
                    variantName: "Tekst podstawowy",
                    languageCode: languageCode,
                    celebrationName: universalisCelebration(in: dayPage),
                    liturgicalColor: nil,
                    offices: offices,
                    sourceImportID: importID,
                    sourceIdentifier: sourceURL.lastPathComponent,
                    sourceTitle: sourceTitle
                ))
            }
            if let progress { await progress(.init(completedDocuments: index + 1, totalDocuments: links.count, elapsed: 0)) }
        }
        let mergedDays = mergedUniversalisDays(days)
        guard !mergedDays.isEmpty else { throw BrewiarzEPUBImportError.noOffices }
        return .init(days: mergedDays, sourceTitle: sourceTitle, skippedDocumentCount: links.count - days.count)
    }

    private static func mergedUniversalisDays(_ days: [OfflineBreviaryDay]) -> [OfflineBreviaryDay] {
        var result: [BreviaryCivilDate: OfflineBreviaryDay] = [:]
        for day in days {
            guard var existing = result[day.date] else {
                result[day.date] = day
                continue
            }
            for office in day.offices {
                guard let index = existing.offices.firstIndex(where: { $0.key == office.key }) else {
                    existing.offices.append(office)
                    continue
                }
                if office.cards.count > existing.offices[index].cards.count {
                    existing.offices[index] = office
                }
            }
            if existing.celebrationName == nil {
                existing.celebrationName = day.celebrationName
            }
            result[day.date] = existing
        }
        return result.values.sorted { $0.date < $1.date }
    }

    private static func universalisCelebration(in xhtml: String) -> String? {
        guard let match = captures(in: xhtml, pattern: #"<strong>([^<]+)</strong>"#).first,
              let title = match.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return nil
        }
        return title
    }

    private static func universalisEntryName(
        for href: String,
        in archive: SimpleZIPArchive
    ) -> String? {
        let path = href
            .split(separator: "#", maxSplits: 1)
            .first
            .map(String.init) ?? href
        guard !path.isEmpty else { return nil }
        if archive.entryNames.contains(path) { return path }
        return archive.entryNames.first { $0.hasSuffix("/\(path)") }
    }

    private static func universalisOfficeKey(_ title: String) -> BrewiarzPrayerKey? {
        let text = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        if text.contains("readings at mass") || text.contains("missa") { return .msza }
        if text.contains("invitatory") || text.contains("invitatorium") { return .wezwanie }
        if text.contains("office of readings") || text.contains("officium lectionis") { return .godzinaCzytan }
        if text.contains("morning prayer") || text.contains("laudes") { return .jutrznia }
        if text.contains("mid-morning") || text.contains("tertiam") || text.contains("tertia") { return .modlitwaPrzedpoludniowa }
        if text.contains("midday") || text.contains("sextam") || text.contains("sexta") { return .modlitwaPoludniowa }
        if text.contains("afternoon prayer") || text.contains("nonam") || text.contains("nona") { return .modlitwaPopoludniowa }
        if text.contains("evening prayer") || text.contains("vesper") { return .nieszpory }
        if text.contains("night prayer") || text.contains("completor") { return .kompleta }
        return nil
    }

    private static func universalisDate(_ text: String) -> BreviaryCivilDate? {
        let months = ["january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12, "ianuarii": 1, "februarii": 2, "martii": 3, "aprilis": 4, "maii": 5, "iunii": 6, "iulii": 7, "augusti": 8, "septembris": 9, "octobris": 10, "novembris": 11, "decembris": 12]
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        guard let match = captures(in: normalized, pattern: #"(\d{1,2})\s+([a-z]+)\s+(\d{4})"#).first, match.count == 3,
              let day = Int(match[0]), let month = months[match[1]], let year = Int(match[2]) else { return nil }
        return .init(year: year, month: month, day: day)
    }

    private static func captures(in text: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        }
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
            let sourceOfficeTitle = definition.key == .msza
                ? "Teksty Mszy św."
                : definition.key.displayName
            let meaningful = discardNavigationAndMetadata(parsedLines, officeTitle: sourceOfficeTitle)
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

    static func selectedDailyDocuments(
        from names: [String],
        preferenceOrder: [String],
        maximumVariantsPerDay: Int = 1,
        documentText: (String) -> String? = { _ in nil }
    ) -> [String] {
        let daily = names.filter(isDailyBreviaryDocument)
        let grouped = Dictionary(grouping: daily) { name in
            let stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent.lowercased()
            return String(stem.prefix(4))
        }
        return grouped.keys.sorted().compactMap { dateKey in
            let documents = grouped[dateKey, default: []].sorted()
            var selected: [String] = []
            var usedCategories = Set<String>()
            var selectedCategoryCount = 0
            for category in BreviaryVariantPreferences.normalizedOrder(preferenceOrder) {
                let matchingDocuments = documents.filter { document in
                    let identifier = parseVariantIdentifier(document)
                    let title = documentText(document).flatMap(parseVariantName) ?? ""
                    return BreviaryVariantPreferences.categoryIdentifier(
                        for: title,
                        technicalIdentifier: identifier
                    ) == category && !usedCategories.contains(category)
                }
                guard !matchingDocuments.isEmpty else { continue }
                if category == "wspomnienie-dowolne" {
                    selected.append(contentsOf: matchingDocuments)
                } else if let document = matchingDocuments.first {
                    selected.append(document)
                }
                usedCategories.insert(category)
                selectedCategoryCount += 1
                if selectedCategoryCount == max(1, maximumVariantsPerDay) { break }
            }
            if selected.isEmpty, let fallback = documents.first {
                selected.append(fallback)
            }
            return selected
        }
        .flatMap { $0 }
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
        if let name = parseVariantName(xhtml) { return name }
        let prefix = xhtml.range(of: "U paulinów", options: [.caseInsensitive, .diacriticInsensitive]) != nil
            ? "U paulinów"
            : nil
        switch identifier {
        case "p": return prefix ?? "Tekst podstawowy"
        case "w": return prefix ?? "Wspomnienie"
        default: return prefix ?? "Wariant \(identifier.uppercased())"
        }
    }

    private static func parseVariantName(_ xhtml: String) -> String? {
        guard let match = xhtml.range(of: #"class=[\"']spis2[\"'][^>]*>(.*?)</div>"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let raw = String(xhtml[match])
            .replacingOccurrences(of: #"^[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
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
            "kartka z kalendarza", "inne oficja", "wykaz obchodów",
            "wczoraj", "dzisiaj", "copyright by", "opracowanie i edycja", "Na końcu tej pieśni nie mówi się Chwała Ojcu."
        ]
        let normalizedOfficeTitle = normalizedForComparison(officeTitle)
        let otherOfficeTitles = Set(
            BrewiarzPrayerKey.allCases
                .map { normalizedForComparison($0.displayName) }
                .filter { $0 != normalizedOfficeTitle }
        )
        var didFindOfficeTitle = !lines.contains {
            normalizedForComparison($0.text) == normalizedOfficeTitle
        }
        var discardingCanonicalPrayer = false
        var discardingPsalmComment = false
        var result: [OfflineBreviaryLine] = []
        for var line in lines {
            let lower = line.text.lowercased()
            let normalizedLine = normalizedForComparison(line.text)
            if navigationPhrases.contains(where: lower.contains) { continue }
            if line.role == .rubric
                || lower.hasPrefix("excerpt from")
                || lower == "brewiarz.pl" {
                continue
            }
            if otherOfficeTitles.contains(normalizedLine) { continue }
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
                guard normalizedLine == normalizedOfficeTitle else { continue }
                didFindOfficeTitle = true
                line.role = .heading
                result.append(line)
                continue
            }
            if normalizedLine == normalizedOfficeTitle,
               result.last.map({ normalizedForComparison($0.text) }) == normalizedLine {
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
            of: #"(?i)^((pierwsze|drugie|trzecie|[123]\.?|i{1,3}\.?)\s+czytanie|antyfona|wprowadzenie|akt pokuty|kolekta|psalm|pieśń|kantyk|hymn|czytanie|aklamacja|ewangelia|responsorium|prośby|modlitwa|prefacja|przed błogosławieństwem|propozycja śpiewów|te deum)(\s|$)"#,
            options: [.regularExpression, .diacriticInsensitive]
        ) != nil
    }

    private static func paginate(
        _ lines: [OfflineBreviaryLine],
        initialTitle: String? = nil
    ) -> [OfflineBreviaryCard] {
        let maxCharacters = 1024
        let maxLines = 12
        var cards: [OfflineBreviaryCard] = []
        var current: [OfflineBreviaryLine] = []
        var characterCount = 0
        var sectionTitle = initialTitle
        var awaitingNumberedAntiphonTitle = false
        var intercessionsOnCard = 0
        var inIntercessions = false
        var intercessionResponse: String?
        var contentGroupID: UUID?
        var contentGroupHasBody = false

        func flush() {
            guard !current.isEmpty else { return }
            cards.append(OfflineBreviaryCard(
                title: sectionTitle,
                lines: current,
                contentGroupID: contentGroupID
            ))
            current = []
            characterCount = 0
            intercessionsOnCard = 0
        }
        var nextFlush = false
        let paginatedLines = lines.flatMap { splitForPagination($0, maximumCharacters: maxCharacters) }
        var lineIndex = 0
        while lineIndex < paginatedLines.count {
            var line = paginatedLines[lineIndex]
            if line.role == .prayerReference {
                flush()
                cards.append(OfflineBreviaryCard(title: line.canonicalPrayerName, lines: [line]))
                sectionTitle = nil
                awaitingNumberedAntiphonTitle = false
                inIntercessions = false
                intercessionResponse = nil
                contentGroupID = nil
                contentGroupHasBody = false
                lineIndex += 1
                continue
            }
            let numberedAntiphon = isNumberedAntiphon(line.text)
            if(nextFlush)
            {
                flush()
                nextFlush = false
            }
            if numberedAntiphon {
                flush()
                sectionTitle = nil
                contentGroupID = nil
                contentGroupHasBody = false
                awaitingNumberedAntiphonTitle = true
                nextFlush = true
            }
            if(line.text.range(
                of: #"^\s*[13579]\s+"#,
                options: .regularExpression
            ) != nil)
            {
                flush()
            }
            if(line.text.range(
                of: #"^\s*[2468]\s+"#,
                options: .regularExpression
            ) != nil)
            {
                line.text = "\n"+line.text
            }
            if line.role == .heading {
                if inIntercessions && isIntercessionContinuation(line.text) {
                    line.role = .body
                } else if awaitingNumberedAntiphonTitle {
                    sectionTitle = line.text
                    awaitingNumberedAntiphonTitle = false
                    if isSemanticSectionHeading(line.text) {
                        contentGroupID = UUID()
                        contentGroupHasBody = false
                    }
                } else {
                    flush()
                    sectionTitle = line.text
                    if isSemanticSectionHeading(line.text),
                       contentGroupID == nil || contentGroupHasBody {
                        contentGroupID = UUID()
                        contentGroupHasBody = false
                    }
                    inIntercessions = isIntercessionsHeading(line.text)
                    intercessionResponse = nil
                }
            }

            if inIntercessions,
               !isIntercessionContinuation(line.text),
               lineIndex + 1 < paginatedLines.count,
               isIntercessionContinuation(paginatedLines[lineIndex + 1].text) {
                var continuation = paginatedLines[lineIndex + 1]
                continuation.role = .body
                var group = [line, continuation]
                var consumedLineCount = 2

                if lineIndex + 2 < paginatedLines.count {
                    let following = paginatedLines[lineIndex + 2]
                    if intercessionResponse == nil,
                       following.text == current.last?.text {
                        intercessionResponse = following.text
                    }
                    if following.text == intercessionResponse {
                        group.append(following)
                        consumedLineCount += 1
                    }
                }

                let groupCharacterCount = group.reduce(0) { $0 + $1.text.count }
                let wouldOverflow = !current.isEmpty && (
                    characterCount + groupCharacterCount > maxCharacters
                        || current.count + group.count > maxLines
                        || intercessionsOnCard >= 3
                )
                if wouldOverflow { flush() }
                current.append(contentsOf: group)
                characterCount += groupCharacterCount
                intercessionsOnCard += 1
                contentGroupHasBody = true
                lineIndex += consumedLineCount
                continue
            }

            let wouldOverflow = !current.isEmpty
                && (characterCount + line.text.count > maxCharacters || current.count >= maxLines)
            if wouldOverflow { flush() }
            current.append(line)
            characterCount += line.text.count
            if contentGroupID != nil, line.role != .heading {
                contentGroupHasBody = true
            }
            lineIndex += 1
        }
        flush()
        return annotatedContentGroups(in: cards)
    }

    private static func isIntercessionsHeading(_ text: String) -> Bool {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        ) == "prosby"
    }

    private static func isIntercessionContinuation(_ text: String) -> Bool {
        text.range(of: #"^\s*[-–—]\s+"#, options: .regularExpression) != nil
    }

    private static func isNumberedAntiphon(_ text: String) -> Bool {
        text.range(
            of: #"^\s*\d+\s+ant\."#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil || text.range(
            of: #"^\s*Psalm\s+\d+"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil || text.range(
            of: #"^\s*Pieśń\s+\("#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func annotatedContentGroups(
        in cards: [OfflineBreviaryCard]
    ) -> [OfflineBreviaryCard] {
        var result = cards
        var startIndex = 0

        while startIndex < result.count {
            guard let groupID = result[startIndex].contentGroupID else {
                startIndex += 1
                continue
            }

            var endIndex = startIndex + 1
            while endIndex < result.count,
                  result[endIndex].contentGroupID == groupID {
                endIndex += 1
            }

            let groupTitle = result[startIndex].title
            var firstContentIndex = startIndex
            while firstContentIndex < endIndex,
                  !result[firstContentIndex].lines.isEmpty,
                  result[firstContentIndex].lines.allSatisfy({ $0.role == .heading }) {
                firstContentIndex += 1
            }

            let contentPartCount = endIndex - firstContentIndex
            for index in startIndex..<firstContentIndex {
                result[index].partIndex = 0
                result[index].partCount = contentPartCount
                result[index].title = groupTitle
            }
            for index in firstContentIndex..<endIndex {
                let partIndex = index - firstContentIndex + 1
                result[index].partIndex = partIndex
                result[index].partCount = contentPartCount
                if contentPartCount > 1, let groupTitle {
                    result[index].title = "\(groupTitle) (\(partIndex)/\(contentPartCount))"
                }
            }
            startIndex = endIndex
        }

        startIndex = 0
        while startIndex < result.count {
            guard result[startIndex].contentGroupID == nil,
                  let title = result[startIndex].title else {
                startIndex += 1
                continue
            }

            var endIndex = startIndex + 1
            while endIndex < result.count,
                  result[endIndex].contentGroupID == nil,
                  result[endIndex].title == title {
                endIndex += 1
            }

            let partCount = endIndex - startIndex
            if partCount > 1 {
                for index in startIndex..<endIndex {
                    result[index].title = "\(title) (\(index - startIndex + 1)/\(partCount))"
                }
            }
            startIndex = endIndex
        }

        return result
    }

    private static func splitForPagination(
        _ line: OfflineBreviaryLine,
        maximumCharacters: Int
    ) -> [OfflineBreviaryLine] {
        guard line.role != .heading,
              line.role != .prayerReference,
              line.text.count > maximumCharacters else { return [line] }

        var chunks: [String] = []
        var currentChunk = ""

        for sentence in sentenceSegments(in: line.text) {
            if sentence.count > maximumCharacters {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                    currentChunk = ""
                }
                chunks.append(contentsOf: balancedWordChunks(
                    sentence,
                    maximumCharacters: maximumCharacters
                ))
                continue
            }

            let candidate = currentChunk.isEmpty ? sentence : "\(currentChunk) \(sentence)"
            if candidate.count <= maximumCharacters {
                currentChunk = candidate
            } else {
                if !currentChunk.isEmpty { chunks.append(currentChunk) }
                currentChunk = sentence
            }
        }
        if !currentChunk.isEmpty { chunks.append(currentChunk) }

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

    private static func sentenceSegments(in text: String) -> [String] {
        let normalizedText = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !normalizedText.isEmpty else { return [] }

        let characters = Array(normalizedText)
        var sentences: [String] = []
        var current = ""
        let terminators: Set<Character> = [".", "!", "?", "…"]

        for index in characters.indices {
            let character = characters[index]
            current.append(character)
            guard terminators.contains(character) else { continue }

            let nextIndex = characters.index(after: index)
            guard nextIndex == characters.endIndex || characters[nextIndex].isWhitespace else {
                continue
            }
            if character == ".", isKnownSentenceAbbreviation(current) {
                continue
            }

            let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            current = ""
        }

        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty { sentences.append(remainder) }
        return sentences
    }

    private static func isKnownSentenceAbbreviation(_ text: String) -> Bool {
        let token = text
            .split(whereSeparator: { $0.isWhitespace })
            .last
            .map(String.init)?
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "„”\"'()[]{}")) ?? ""
        let abbreviations: Set<String> = [
            "św.", "np.", "itd.", "itp.", "por.", "zob.", "ks.", "bp.",
            "o.", "nr.", "r.", "w.", "ww.", "tzn.", "tj.", "dr.", "prof."
        ]
        if abbreviations.contains(token) { return true }
        return token.hasSuffix(".") && token.dropLast().count == 1
    }

    private static func balancedWordChunks(
        _ text: String,
        maximumCharacters: Int
    ) -> [String] {
        var chunks: [[String]] = []
        var currentWords: [String] = []
        var currentCharacterCount = 0

        for word in text.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            let separatorCount = currentWords.isEmpty ? 0 : 1
            if !currentWords.isEmpty,
               currentCharacterCount + separatorCount + word.count > maximumCharacters {
                chunks.append(currentWords)
                currentWords = [word]
                currentCharacterCount = word.count
            } else {
                currentWords.append(word)
                currentCharacterCount += separatorCount + word.count
            }
        }
        if !currentWords.isEmpty { chunks.append(currentWords) }

        if chunks.count >= 2,
           chunks[chunks.count - 1].count == 1,
           chunks[chunks.count - 2].count > 2 {
            let movedWord = chunks[chunks.count - 2].removeLast()
            let rebalancedLastChunk = ([movedWord] + chunks[chunks.count - 1])
                .joined(separator: " ")
            if rebalancedLastChunk.count <= maximumCharacters {
                chunks[chunks.count - 1].insert(movedWord, at: 0)
            } else {
                chunks[chunks.count - 2].append(movedWord)
            }
        }

        return chunks.map { $0.joined(separator: " ") }
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
        case .msza: englishOffice = "Mass"
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
        Date: \(date.id).
        Time slot: \(office.displayName) (\(englishOffice)).
        Name found in the Polish source: \(celebration ?? "none specified").
        Color found in the source: \(liturgicalColor ?? "not specified").
        Source excerpts:
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
            else if Self.isReadingProclamation(text) { role = .body }
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
            of: #"(?i)^((pierwsze|drugie|trzecie|[123]\.?|i{1,3}\.?)\s+czytanie|antyfona|wprowadzenie|akt pokuty|kolekta|psalm|pieśń|kantyk|hymn|czytanie|aklamacja|ewangelia|responsorium|prośby|modlitwa|prefacja|przed błogosławieństwem|propozycja śpiewów|te deum)(\s|$)"#,
            options: [.regularExpression, .diacriticInsensitive]
        ) != nil
    }

    private static func isReadingProclamation(_ text: String) -> Bool {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        return folded.hasPrefix("czytanie z ")
            || folded.hasPrefix("czytanie wedlug ")
            || folded.hasPrefix("slowa ewangelii ")
            || folded.hasPrefix("poczatek ewangelii ")
            || folded.hasPrefix("zakonczenie ewangelii ")
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
