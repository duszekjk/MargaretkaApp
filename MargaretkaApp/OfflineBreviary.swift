import Foundation
import SwiftUI
internal import Combine

nonisolated struct BreviaryCivilDate: Codable, Hashable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var id: String { String(format: "%04d-%02d-%02d", year, month, day) }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .brewiarzWarsaw) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    var date: Date? {
        Calendar.brewiarzWarsaw.date(from: DateComponents(year: year, month: month, day: day))
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension Calendar {
    nonisolated static var brewiarzWarsaw: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        return calendar
    }
}

nonisolated enum OfflineBreviaryLineRole: String, Codable, Hashable, Sendable {
    case heading
    case rubric
    case antiphon
    case choirLeft
    case choirRight
    case leader
    case response
    case body
    case prayerReference
}

nonisolated struct OfflineBreviaryLine: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var role: OfflineBreviaryLineRole
    var text: String
    var canonicalPrayerName: String?
    var emphasized: Bool
    var italic: Bool

    init(
        id: UUID = UUID(),
        role: OfflineBreviaryLineRole,
        text: String,
        canonicalPrayerName: String? = nil,
        emphasized: Bool = false,
        italic: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.canonicalPrayerName = canonicalPrayerName
        self.emphasized = emphasized
        self.italic = italic
    }
}

nonisolated struct OfflineBreviaryCard: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String?
    var lines: [OfflineBreviaryLine]

    init(id: UUID = UUID(), title: String? = nil, lines: [OfflineBreviaryLine]) {
        self.id = id
        self.title = title
        self.lines = lines
    }
}

nonisolated struct OfflineBreviaryOffice: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var key: BrewiarzPrayerKey
    var title: String
    var cards: [OfflineBreviaryCard]
    var contentFingerprint: String
    var imageFilename: String?
    var imagePrompt: String?
    var imageSourceText: String?

    init(
        id: UUID = UUID(),
        key: BrewiarzPrayerKey,
        title: String? = nil,
        cards: [OfflineBreviaryCard],
        contentFingerprint: String,
        imageFilename: String? = nil,
        imagePrompt: String? = nil,
        imageSourceText: String? = nil
    ) {
        self.id = id
        self.key = key
        self.title = title ?? key.displayName
        self.cards = cards
        self.contentFingerprint = contentFingerprint
        self.imageFilename = imageFilename
        self.imagePrompt = imagePrompt
        self.imageSourceText = imageSourceText
    }
}

nonisolated struct OfflineBreviaryDay: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var date: BreviaryCivilDate
    var variantIdentifier: String
    var variantName: String
    var celebrationName: String?
    var liturgicalColor: String?
    var offices: [OfflineBreviaryOffice]
    var sourceImportID: UUID
    var sourceIdentifier: String
    var sourceTitle: String
    var importedAt: Date

    init(
        id: UUID = UUID(),
        date: BreviaryCivilDate,
        variantIdentifier: String,
        variantName: String,
        celebrationName: String? = nil,
        liturgicalColor: String? = nil,
        offices: [OfflineBreviaryOffice],
        sourceImportID: UUID,
        sourceIdentifier: String,
        sourceTitle: String,
        importedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.variantIdentifier = variantIdentifier
        self.variantName = variantName
        self.celebrationName = celebrationName
        self.liturgicalColor = liturgicalColor
        self.offices = offices
        self.sourceImportID = sourceImportID
        self.sourceIdentifier = sourceIdentifier
        self.sourceTitle = sourceTitle
        self.importedAt = importedAt
    }

    var stableIdentity: String {
        "\(date.id)|\(variantIdentifier.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL")))"
    }
}

@MainActor
enum BreviaryPrayerTargetFactory {
    static func missingTargets(
        for days: [OfflineBreviaryDay],
        prayers: [Prayer],
        existingTargets: [Priest]
    ) -> [Priest] {
        let importedKeys = Set(days.flatMap(\.offices).map(\.key))
        return BrewiarzPrayerKey.allCases.compactMap { key in
            guard importedKeys.contains(key),
                  let prayer = prayers.first(where: {
                      if case .brewiarz(let prayerKey) = $0.content { return prayerKey == key }
                      return false
                  }),
                  !existingTargets.contains(where: {
                      $0.category == .prayer
                          && (normalized($0.displayName) == normalized(key.displayName)
                              || assignedPrayerIDs(in: $0).contains(prayer.id))
                  }) else { return nil }

            return Priest(
                id: targetID(for: key),
                firstName: key.displayName,
                lastName: "",
                title: "",
                category: .prayer,
                assignedPrayerGroups: [
                    AssignedPrayerGroup(id: UUID(), prayerIds: [prayer.id], repeatCount: 1)
                ],
                schedule: .suggested(forPrayerName: key.displayName),
                lastModified: .now,
                notificationTitle: key.displayName,
                notificationMessage: ""
            )
        }
    }

    private static func assignedPrayerIDs(in target: Priest) -> Set<UUID> {
        func ids(in group: AssignedPrayerGroup) -> [UUID] {
            group.items.flatMap { item in
                switch item {
                case .prayer(let id): return [id]
                case .subgroup(let index):
                    guard group.subgroups.indices.contains(index) else { return [] }
                    return ids(in: group.subgroups[index])
                }
            }
        }
        return Set(target.assignedPrayerGroups.flatMap(ids(in:)))
    }

    private static func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
    }

    private static func targetID(for key: BrewiarzPrayerKey) -> UUID {
        let ids: [BrewiarzPrayerKey: UUID] = [
            .wezwanie: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000001")!,
            .godzinaCzytan: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000002")!,
            .jutrznia: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000003")!,
            .modlitwaPrzedpoludniowa: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000004")!,
            .modlitwaPoludniowa: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000005")!,
            .modlitwaPopoludniowa: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000006")!,
            .nieszpory: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000007")!,
            .kompleta: UUID(uuidString: "7c2a9e34-50da-4b92-9000-000000000008")!
        ]
        return ids[key]!
    }
}

@MainActor
final class OfflineBreviaryStore: ObservableObject {
    static let storageKey = "offline_breviary_v1"
    static let retentionDays = 3

    @Published private(set) var days: [OfflineBreviaryDay] = []
    private var generatingOfficeIDs = Set<UUID>()

    init(referenceDate: Date = .now) {
        days = LocalDatabase.shared.load(from: Self.storageKey)
        removeExpired(referenceDate: referenceDate)
    }

    func matchingDays(for date: Date) -> [OfflineBreviaryDay] {
        let civilDate = BreviaryCivilDate(date: date)
        return days
            .filter { $0.date == civilDate }
            .sorted { lhs, rhs in
                if lhs.variantIdentifier == "p" { return true }
                if rhs.variantIdentifier == "p" { return false }
                return lhs.variantName.localizedCaseInsensitiveCompare(rhs.variantName) == .orderedAscending
            }
    }

    func office(for key: BrewiarzPrayerKey, date: Date, preferredVariant: String? = nil) -> OfflineBreviaryOffice? {
        let candidates = matchingDays(for: date)
        let selectedDay = preferredVariant.flatMap { preferred in
            candidates.first { $0.variantIdentifier == preferred }
        } ?? candidates.first
        return selectedDay?.offices.first { $0.key == key }
    }

    func day(containing officeID: UUID) -> OfflineBreviaryDay? {
        days.first { day in day.offices.contains { $0.id == officeID } }
    }

    func replaceAll(with importedDays: [OfflineBreviaryDay], referenceDate: Date = .now) {
        days = Self.removingExpired(from: importedDays, referenceDate: referenceDate)
        sortAndSave()
    }

    func upsert(_ importedDays: [OfflineBreviaryDay], referenceDate: Date = .now) {
        for imported in Self.removingExpired(from: importedDays, referenceDate: referenceDate) {
            if let index = days.firstIndex(where: { $0.stableIdentity == imported.stableIdentity }) {
                days[index] = imported
            } else {
                days.append(imported)
            }
        }
        removeExpired(referenceDate: referenceDate)
        sortAndSave()
    }

    func removeExpired(referenceDate: Date = .now) {
        let retained = Self.removingExpired(from: days, referenceDate: referenceDate)
        guard retained.count != days.count else { return }
        let retainedImageNames = Set(retained.flatMap(\.offices).compactMap(\.imageFilename))
        let removedImageNames = Set(days.flatMap(\.offices).compactMap(\.imageFilename)).subtracting(retainedImageNames)
        days = retained
        removedImageNames.forEach(Self.removeImage(named:))
        sortAndSave()
    }

    func delete(dayID: UUID) {
        guard let removed = days.first(where: { $0.id == dayID }) else { return }
        days.removeAll { $0.id == dayID }
        removeOrphanedImages(from: removed.offices)
        sortAndSave()
    }

    func delete(officeID: UUID) {
        guard let dayIndex = days.firstIndex(where: { day in day.offices.contains { $0.id == officeID } }),
              let officeIndex = days[dayIndex].offices.firstIndex(where: { $0.id == officeID }) else { return }
        let removed = days[dayIndex].offices.remove(at: officeIndex)
        if days[dayIndex].offices.isEmpty {
            days.remove(at: dayIndex)
        }
        removeOrphanedImages(from: [removed])
        sortAndSave()
    }

    func delete(sourceImportID: UUID) {
        let removed = days.filter { $0.sourceImportID == sourceImportID }
        days.removeAll { $0.sourceImportID == sourceImportID }
        removeOrphanedImages(from: removed.flatMap(\.offices))
        sortAndSave()
    }

    func delete(from startDate: Date, through endDate: Date) {
        let start = BreviaryCivilDate(date: min(startDate, endDate))
        let end = BreviaryCivilDate(date: max(startDate, endDate))
        let removed = days.filter { $0.date >= start && $0.date <= end }
        guard !removed.isEmpty else { return }
        days.removeAll { $0.date >= start && $0.date <= end }
        removeOrphanedImages(from: removed.flatMap(\.offices))
        sortAndSave()
    }

    func generateImageIfNeeded(for officeID: UUID) async {
        guard !generatingOfficeIDs.contains(officeID),
              let dayIndex = days.firstIndex(where: { $0.offices.contains { $0.id == officeID } }),
              let officeIndex = days[dayIndex].offices.firstIndex(where: { $0.id == officeID }),
              days[dayIndex].offices[officeIndex].imageFilename == nil else { return }
        generatingOfficeIDs.insert(officeID)
        let office = days[dayIndex].offices[officeIndex]
        let date = days[dayIndex].date
        defer { generatingOfficeIDs.remove(officeID) }

        guard let data = await BreviaryImageGenerator.shared.generateImageData(for: office) else { return }
        let filename = "\(date.id)-\(office.key.rawValue)-\(office.contentFingerprint).jpg"
        let destination = Self.imageDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: destination, options: .atomic)
            guard days.indices.contains(dayIndex),
                  days[dayIndex].offices.indices.contains(officeIndex),
                  days[dayIndex].offices[officeIndex].id == officeID else {
                try? FileManager.default.removeItem(at: destination)
                return
            }
            days[dayIndex].offices[officeIndex].imageFilename = filename
            sortAndSave()
        } catch {
            print("Failed to cache breviary image: \(error.localizedDescription)")
        }
    }

    func deleteImage(for officeID: UUID) {
        guard let dayIndex = days.firstIndex(where: { $0.offices.contains { $0.id == officeID } }),
              let officeIndex = days[dayIndex].offices.firstIndex(where: { $0.id == officeID }),
              let filename = days[dayIndex].offices[officeIndex].imageFilename else { return }
        days[dayIndex].offices[officeIndex].imageFilename = nil
        Self.removeImage(named: filename)
        sortAndSave()
    }

    func removeUnreferencedImages() {
        let referenced = Set(days.flatMap(\.offices).compactMap(\.imageFilename))
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Self.imageDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files where !referenced.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func removeAllStoredImages() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: imageDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func removingExpired(
        from days: [OfflineBreviaryDay],
        referenceDate: Date,
        calendar: Calendar = .brewiarzWarsaw
    ) -> [OfflineBreviaryDay] {
        days.filter { !isExpired($0.date, referenceDate: referenceDate, calendar: calendar) }
    }

    static func isExpired(
        _ date: BreviaryCivilDate,
        referenceDate: Date,
        calendar: Calendar = .brewiarzWarsaw
    ) -> Bool {
        guard let officeDate = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)),
              let expiresAt = calendar.date(byAdding: .day, value: retentionDays, to: officeDate) else {
            return false
        }
        return expiresAt <= calendar.startOfDay(for: referenceDate)
    }

    private func sortAndSave() {
        days.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.variantName.localizedCaseInsensitiveCompare($1.variantName) == .orderedAscending
        }
        LocalDatabase.shared.save(days, as: Self.storageKey)
    }

    private func removeOrphanedImages(from offices: [OfflineBreviaryOffice]) {
        let retainedNames = Set(days.flatMap(\.offices).compactMap(\.imageFilename))
        for name in offices.compactMap(\.imageFilename) where !retainedNames.contains(name) {
            Self.removeImage(named: name)
        }
    }

    private static func removeImage(named filename: String) {
        let url = imageDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    static var imageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("OfflineBreviaryImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
