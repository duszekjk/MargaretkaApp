import Foundation
import SwiftUI
internal import UniformTypeIdentifiers

struct MargaretkaBackup: Codable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var exportedAt: Date
    var purpose: MargaretkaArchivePurpose?
    var preferences: MargaretkaBackupPreferences?
    var prayers: [Prayer]
    var targets: [Priest]
    var sessions: [PrayerSession]
    var offlineBreviaryDays: [OfflineBreviaryDay]
    var assets: [MargaretkaBackupAsset]
}

enum MargaretkaArchivePurpose: String, Codable {
    case dataTransfer
    case fullBackup
}

enum MargaretkaExportSelection: Hashable {
    case allCurrentData
    case prayer(UUID)
    case target(UUID)
    case breviaryOffice(BrewiarzPrayerKey)
    case saintBiographies
}

struct MargaretkaBackupPreferences: Codable, Equatable {
    var prayerSwipeMode: String
    var prayerCompactView: Bool
    var preferredBreviaryVariant: String
    var preferredBreviaryVariantOrder: [String]? = nil

    static func capture(from defaults: UserDefaults = .standard) -> Self {
        Self(
            prayerSwipeMode: defaults.string(forKey: "prayerSwipeMode") ?? PrayerSwipeMode.both.rawValue,
            prayerCompactView: defaults.object(forKey: "prayerCompactView") as? Bool ?? true,
            preferredBreviaryVariant: defaults.string(forKey: BreviaryVariantPreferences.legacyStorageKey) ?? "p",
            preferredBreviaryVariantOrder: BreviaryVariantPreferences.load(from: defaults)
        )
    }

    func restore(to defaults: UserDefaults = .standard) {
        defaults.set(prayerSwipeMode, forKey: "prayerSwipeMode")
        defaults.set(prayerCompactView, forKey: "prayerCompactView")
        BreviaryVariantPreferences.save(
            preferredBreviaryVariantOrder ?? [preferredBreviaryVariant],
            to: defaults
        )
    }
}

struct MargaretkaBackupAsset: Codable {
    enum Kind: String, Codable {
        case audio
        case offlineBreviaryImage
    }

    var kind: Kind
    var filename: String
    var data: Data
}

enum MargaretkaBackupError: LocalizedError {
    case unsupportedSchema(Int)
    case invalidFilename(String)
    case notJSONBackup

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "Ta kopia używa nieobsługiwanej wersji formatu (\(version))."
        case .invalidFilename(let filename):
            return "Kopia zawiera nieprawidłową nazwę pliku: \(filename)"
        case .notJSONBackup:
            return "Wybrany plik nie jest kopią Margaretki w formacie JSON."
        }
    }
}

enum BackupConflictResolution: String, CaseIterable, Identifiable {
    case keepExisting
    case useImported
    case keepBoth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keepExisting: return "To samo — zachowaj obecne"
        case .useImported: return "To samo — użyj importowanego"
        case .keepBoth: return "Różne — zachowaj oba"
        }
    }
}

struct BackupImportConflict: Identifiable {
    enum EntityKind {
        case prayer(existingID: UUID, importedID: UUID)
        case target(existingID: UUID, importedID: UUID)
        case breviary(existingID: UUID, importedID: UUID)
    }

    let id = UUID()
    let title: String
    let existingSummary: String
    let importedSummary: String
    let kind: EntityKind
}

struct BackupImportPlan {
    let backup: MargaretkaBackup
    let conflicts: [BackupImportConflict]
}

struct BackupImportReport {
    let prayersAdded: Int
    let targetsAdded: Int
    let sessionsAdded: Int
    let breviaryDatesAdded: Int
    let breviaryVariantsAdded: Int

    var summary: String {
        "Dodano: \(prayersAdded) modlitw, \(targetsAdded) osób lub modlitw złożonych, \(sessionsAdded) wpisów historii oraz brewiarz: \(breviaryDatesAdded) dni kalendarzowych (\(breviaryVariantsAdded) wariantów dziennych)."
    }
}

struct FullBackupRestoreReport {
    let prayers: Int
    let targets: Int
    let sessions: Int
    let breviaryDays: Int
    let restoredPreferences: Bool

    var summary: String {
        let preferencesText = restoredPreferences ? " Ustawienia widoku również przywrócono." : ""
        return "Przywrócono: \(prayers) modlitw, \(targets) osób lub modlitw złożonych, \(sessions) wpisów historii i \(breviaryDays) dni brewiarza.\(preferencesText)"
    }
}

enum MargaretkaBackupService {
    static func export(
        prayers: [Prayer],
        targets: [Priest],
        offlineDays: [OfflineBreviaryDay],
        purpose: MargaretkaArchivePurpose = .dataTransfer,
        selection: MargaretkaExportSelection = .allCurrentData
    ) throws -> URL {
        let sessions: [PrayerSession] = purpose == .fullBackup
            ? LocalDatabase.shared.load(from: PrayerSessionStore.saveKey)
            : []
        let backup = archive(
            prayers: prayers,
            targets: targets,
            sessions: sessions,
            offlineDays: offlineDays,
            purpose: purpose,
            selection: selection
        )
        return try write(backup)
    }

    static func archive(
        prayers: [Prayer],
        targets: [Priest],
        sessions: [PrayerSession],
        offlineDays: [OfflineBreviaryDay],
        purpose: MargaretkaArchivePurpose,
        selection: MargaretkaExportSelection = .allCurrentData
    ) -> MargaretkaBackup {
        let content = purpose == .fullBackup
            ? (prayers: prayers, targets: targets, days: offlineDays)
            : selectedContent(
                prayers: prayers,
                targets: targets,
                offlineDays: offlineDays,
                selection: selection
            )
        return MargaretkaBackup(
            schemaVersion: MargaretkaBackup.currentSchemaVersion,
            exportedAt: .now,
            purpose: purpose,
            preferences: purpose == .fullBackup ? .capture() : nil,
            prayers: content.prayers,
            targets: content.targets,
            sessions: purpose == .fullBackup ? sessions : [],
            offlineBreviaryDays: content.days,
            assets: collectAssets(prayers: content.prayers, offlineDays: content.days)
        )
    }

    private static func write(_ backup: MargaretkaBackup) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(backup)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let prefix = backup.purpose == .fullBackup ? "Margaretka_backup" : "Margaretka_export"
        let filename = "\(prefix)_\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func decode(from url: URL) throws -> MargaretkaBackup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(MargaretkaBackup.self, from: data) else {
            throw MargaretkaBackupError.notJSONBackup
        }
        guard backup.schemaVersion <= MargaretkaBackup.currentSchemaVersion else {
            throw MargaretkaBackupError.unsupportedSchema(backup.schemaVersion)
        }
        return backup
    }

    @MainActor
    static func makeImportPlan(
        backup: MargaretkaBackup,
        prayers: [Prayer],
        targets: [Priest],
        offlineDays: [OfflineBreviaryDay]
    ) -> BackupImportPlan {
        var conflicts: [BackupImportConflict] = []

        for imported in backup.prayers {
            if let existing = prayers.first(where: { $0.id == imported.id }), existing != imported {
                conflicts.append(prayerConflict(existing: existing, imported: imported))
            } else if prayers.contains(where: { prayersAreEquivalent($0, imported) }) {
                continue
            } else if let existing = prayers.first(where: { normalized($0.name) == normalized(imported.name) }) {
                conflicts.append(prayerConflict(existing: existing, imported: imported))
            }
        }

        for imported in backup.targets {
            if let existing = targets.first(where: { $0.id == imported.id }), existing != imported {
                conflicts.append(targetConflict(existing: existing, imported: imported))
            } else if targets.contains(where: { targetsAreEquivalent($0, imported) }) {
                continue
            } else if let existing = targets.first(where: {
                $0.category == imported.category && normalized($0.displayName) == normalized(imported.displayName)
            }) {
                conflicts.append(targetConflict(existing: existing, imported: imported))
            }
        }

        for imported in backup.offlineBreviaryDays {
            guard let existing = offlineDays.first(where: { $0.stableIdentity == imported.stableIdentity }) else { continue }
            if officeFingerprints(existing) != officeFingerprints(imported) {
                conflicts.append(
                    BackupImportConflict(
                        title: "Brewiarz \(imported.date.id) — \(imported.variantName)",
                        existingSummary: breviarySummary(existing),
                        importedSummary: breviarySummary(imported),
                        kind: .breviary(existingID: existing.id, importedID: imported.id)
                    )
                )
            }
        }

        return BackupImportPlan(backup: backup, conflicts: conflicts)
    }

    @MainActor
    static func apply(
        plan: BackupImportPlan,
        resolutions: [UUID: BackupConflictResolution],
        prayerStore: PrayerStore,
        targetStore: PriestStore,
        offlineStore: OfflineBreviaryStore
    ) throws -> BackupImportReport {
        let filenameMap = try restoreAssets(plan.backup.assets)
        let conflictsByImportedPrayer = conflictLookup(plan.conflicts, resolutions: resolutions) { kind in
            if case .prayer(_, let importedID) = kind { return importedID }
            return nil
        }
        let conflictsByImportedTarget = conflictLookup(plan.conflicts, resolutions: resolutions) { kind in
            if case .target(_, let importedID) = kind { return importedID }
            return nil
        }
        let conflictsByImportedDay = conflictLookup(plan.conflicts, resolutions: resolutions) { kind in
            if case .breviary(_, let importedID) = kind { return importedID }
            return nil
        }

        var prayers = prayerStore.prayers
        var prayerIDMap: [UUID: UUID] = [:]
        var prayersAdded = 0
        for original in plan.backup.prayers {
            var imported = original
            if let filename = imported.audioFilename {
                imported.audioFilename = filenameMap[assetMapKey(.audio, filename)] ?? filename
            }
            if let existing = prayers.first(where: { prayersAreEquivalent($0, imported) }) {
                prayerIDMap[original.id] = existing.id
                continue
            }
            if let decision = conflictsByImportedPrayer[original.id] {
                switch decision.resolution {
                case .keepExisting:
                    prayerIDMap[original.id] = decision.existingID
                case .useImported:
                    let replacement = prayer(imported, replacingIDWith: decision.existingID)
                    if let index = prayers.firstIndex(where: { $0.id == decision.existingID }) {
                        prayers[index] = replacement
                    }
                    prayerIDMap[original.id] = decision.existingID
                case .keepBoth:
                    let newID = prayers.contains(where: { $0.id == imported.id }) ? UUID() : imported.id
                    imported = prayer(imported, replacingIDWith: newID)
                    prayers.append(imported)
                    prayerIDMap[original.id] = newID
                    prayersAdded += 1
                }
                continue
            }
            let newID = prayers.contains(where: { $0.id == imported.id }) ? UUID() : imported.id
            imported = prayer(imported, replacingIDWith: newID)
            prayers.append(imported)
            prayerIDMap[original.id] = newID
            prayersAdded += 1
        }
        prayerStore.prayers = prayers
        AudioStorage.removeOrphanedFiles(referencedBy: prayers)

        var targets = targetStore.priests
        var targetIDMap: [UUID: UUID] = [:]
        var targetsAdded = 0
        for original in plan.backup.targets {
            var imported = remapping(original, prayerIDs: prayerIDMap)
            if let existing = targets.first(where: { targetsAreEquivalent($0, imported) }) {
                targetIDMap[original.id] = existing.id
                continue
            }
            if let decision = conflictsByImportedTarget[original.id] {
                switch decision.resolution {
                case .keepExisting:
                    targetIDMap[original.id] = decision.existingID
                case .useImported:
                    imported.id = decision.existingID
                    if let index = targets.firstIndex(where: { $0.id == decision.existingID }) {
                        targets[index] = imported
                    }
                    targetIDMap[original.id] = decision.existingID
                case .keepBoth:
                    imported.id = targets.contains(where: { $0.id == imported.id }) ? UUID() : imported.id
                    targets.append(imported)
                    targetIDMap[original.id] = imported.id
                    targetsAdded += 1
                }
                continue
            }
            imported.id = targets.contains(where: { $0.id == imported.id }) ? UUID() : imported.id
            targets.append(imported)
            targetIDMap[original.id] = imported.id
            targetsAdded += 1
        }
        targetStore.priests = targets

        let existingSessions: [PrayerSession] = LocalDatabase.shared.load(from: PrayerSessionStore.saveKey)
        var sessions = existingSessions
        var sessionsAdded = 0
        for imported in plan.backup.sessions where !sessions.contains(where: { $0.id == imported.id }) {
            sessions.append(remapping(imported, prayerIDs: prayerIDMap, targetIDs: targetIDMap))
            sessionsAdded += 1
        }
        LocalDatabase.shared.save(sessions, as: PrayerSessionStore.saveKey)
        MargaretkaWidgetDataWriter.updateStatistics(from: sessions)
        if sessionsAdded > 0 {
            NotificationCenter.default.post(name: .prayerSessionsChanged, object: nil)
        }

        var days = offlineStore.days
        let initialDayCount = days.count
        let initialBreviaryDates = Set(days.map(\.date))
        for original in plan.backup.offlineBreviaryDays {
            var imported = remappingImages(original, filenameMap: filenameMap)
            if OfflineBreviaryStore.isExpired(imported.date, referenceDate: .now) { continue }
            if let existingIndex = days.firstIndex(where: { $0.stableIdentity == imported.stableIdentity }) {
                if officeFingerprints(days[existingIndex]) == officeFingerprints(imported) { continue }
                guard let decision = conflictsByImportedDay[original.id] else { continue }
                switch decision.resolution {
                case .keepExisting:
                    continue
                case .useImported:
                    imported = day(imported, replacingIDWith: days[existingIndex].id)
                    days[existingIndex] = imported
                case .keepBoth:
                    imported = day(imported, replacingIDWith: UUID(), variantSuffix: " (import)")
                    days.append(imported)
                }
            } else {
                if days.contains(where: { $0.id == imported.id }) {
                    imported = day(imported, replacingIDWith: UUID())
                }
                days.append(imported)
            }
        }
        offlineStore.replaceAll(with: days)
        offlineStore.removeUnreferencedImages()

        return BackupImportReport(
            prayersAdded: prayersAdded,
            targetsAdded: targetsAdded,
            sessionsAdded: sessionsAdded,
            breviaryDatesAdded: Set(offlineStore.days.map(\.date)).subtracting(initialBreviaryDates).count,
            breviaryVariantsAdded: max(0, offlineStore.days.count - initialDayCount)
        )
    }

    @MainActor
    static func restoreExactly(
        backup: MargaretkaBackup,
        prayerStore: PrayerStore,
        targetStore: PriestStore,
        offlineStore: OfflineBreviaryStore,
        scheduleData: ScheduleData<Priest>
    ) throws -> FullBackupRestoreReport {
        try validateAssetFilenames(backup.assets)
        AudioStorage.removeAllStoredAudioFiles()
        OfflineBreviaryStore.removeAllStoredImages()
        let filenameMap = try restoreAssetsExactly(backup.assets)
        let restoredPrayers = PrayerStore.deduplicatingBreviaryPrayers(backup.prayers).map { source -> Prayer in
            var prayer = source
            if let filename = source.audioFilename {
                prayer.audioFilename = filenameMap[assetMapKey(.audio, filename)] ?? filename
            }
            return prayer
        }
        let retainedDays = OfflineBreviaryStore.removingExpired(
            from: backup.offlineBreviaryDays.map { remappingImages($0, filenameMap: filenameMap) },
            referenceDate: .now
        )
        let restoredTargets = backup.targets.map { source -> Priest in
            var target = source
            // Pending notification identifiers belong to the device that made the backup.
            // Completion identifiers remain part of the restored statistics state.
            target.notificationIds = []
            return target
        }

        prayerStore.prayers = restoredPrayers
        targetStore.priests = restoredTargets
        scheduleData.items = restoredTargets
        scheduleData.save()
        LocalDatabase.shared.save(backup.sessions, as: PrayerSessionStore.saveKey)
        MargaretkaWidgetDataWriter.updateStatistics(from: backup.sessions)
        NotificationCenter.default.post(name: .prayerSessionsChanged, object: nil)
        offlineStore.replaceAll(with: retainedDays)
        backup.preferences?.restore()

        AudioStorage.removeOrphanedFiles(referencedBy: restoredPrayers)
        offlineStore.removeUnreferencedImages()
        scheduleData.rescheduleAll()

        return FullBackupRestoreReport(
            prayers: restoredPrayers.count,
            targets: restoredTargets.count,
            sessions: backup.sessions.count,
            breviaryDays: retainedDays.count,
            restoredPreferences: backup.preferences != nil
        )
    }

    private static func selectedContent(
        prayers: [Prayer],
        targets: [Priest],
        offlineDays: [OfflineBreviaryDay],
        selection: MargaretkaExportSelection
    ) -> (prayers: [Prayer], targets: [Priest], days: [OfflineBreviaryDay]) {
        switch selection {
        case .allCurrentData:
            return (prayers, targets, offlineDays)

        case .prayer(let prayerID):
            return (prayers.filter { $0.id == prayerID }, [], [])

        case .target(let targetID):
            let selectedTargets = targets.filter { $0.id == targetID }
            let prayerIDs = Set(selectedTargets.flatMap(assignedPrayerIDs))
            return (prayers.filter { prayerIDs.contains($0.id) }, selectedTargets, [])

        case .breviaryOffice(let key):
            let templateIDs = Set(prayers.compactMap { prayer -> UUID? in
                guard case .brewiarz(let prayerKey) = prayer.content, prayerKey == key else { return nil }
                return prayer.id
            })
            let selectedTargets = targets.filter {
                !$0.assignedPrayerGroups.flatMap(assignedPrayerIDs).filter(templateIDs.contains).isEmpty
            }
            let dependencyIDs = templateIDs.union(selectedTargets.flatMap(assignedPrayerIDs))
            let days = offlineDays.compactMap { source -> OfflineBreviaryDay? in
                var day = source
                day.offices = source.offices.filter { $0.key == key }
                day.saintBiography = nil
                return day.offices.isEmpty ? nil : day
            }
            return (prayers.filter { dependencyIDs.contains($0.id) }, selectedTargets, days)

        case .saintBiographies:
            let templateIDs = Set(prayers.compactMap { prayer -> UUID? in
                guard case .saintBiography = prayer.content else { return nil }
                return prayer.id
            })
            let selectedTargets = targets.filter {
                !$0.assignedPrayerGroups.flatMap(assignedPrayerIDs).filter(templateIDs.contains).isEmpty
            }
            let dependencyIDs = templateIDs.union(selectedTargets.flatMap(assignedPrayerIDs))
            let days = offlineDays.compactMap { source -> OfflineBreviaryDay? in
                guard source.saintBiography != nil else { return nil }
                var day = source
                day.offices = []
                return day
            }
            return (prayers.filter { dependencyIDs.contains($0.id) }, selectedTargets, days)
        }
    }

    private static func assignedPrayerIDs(in target: Priest) -> [UUID] {
        target.assignedPrayerGroups.flatMap(assignedPrayerIDs)
    }

    private static func assignedPrayerIDs(in group: AssignedPrayerGroup) -> [UUID] {
        group.items.compactMap { item in
            if case .prayer(let id) = item { return id }
            return nil
        } + group.subgroups.flatMap(assignedPrayerIDs)
    }

    private static func collectAssets(prayers: [Prayer], offlineDays: [OfflineBreviaryDay]) -> [MargaretkaBackupAsset] {
        var assets: [MargaretkaBackupAsset] = []
        if let directory = try? AudioStorage.applicationSupportDirectory(create: false) {
            for filename in Set(prayers.compactMap(\.audioFilename)) {
                let url = directory.appendingPathComponent(filename)
                if let data = try? Data(contentsOf: url) {
                    assets.append(.init(kind: .audio, filename: filename, data: data))
                }
            }
        }
        for filename in Set(offlineDays.flatMap(\.offices).compactMap(\.imageFilename)) {
            let url = OfflineBreviaryStore.imageDirectory.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: url) {
                assets.append(.init(kind: .offlineBreviaryImage, filename: filename, data: data))
            }
        }
        return assets
    }

    private static func restoreAssets(_ assets: [MargaretkaBackupAsset]) throws -> [String: String] {
        var result: [String: String] = [:]
        for asset in assets {
            guard asset.filename == URL(fileURLWithPath: asset.filename).lastPathComponent else {
                throw MargaretkaBackupError.invalidFilename(asset.filename)
            }
            let directory: URL
            switch asset.kind {
            case .audio:
                directory = try AudioStorage.applicationSupportDirectory(create: true)
            case .offlineBreviaryImage:
                directory = OfflineBreviaryStore.imageDirectory
            }
            var filename = asset.filename
            var destination = directory.appendingPathComponent(filename)
            if let current = try? Data(contentsOf: destination), current != asset.data {
                filename = "\(UUID().uuidString)-\(asset.filename)"
                destination = directory.appendingPathComponent(filename)
            }
            if !FileManager.default.fileExists(atPath: destination.path) {
                try asset.data.write(to: destination, options: .atomic)
            }
            result[assetMapKey(asset.kind, asset.filename)] = filename
        }
        return result
    }

    private static func restoreAssetsExactly(_ assets: [MargaretkaBackupAsset]) throws -> [String: String] {
        var result: [String: String] = [:]
        for asset in assets {
            guard asset.filename == URL(fileURLWithPath: asset.filename).lastPathComponent else {
                throw MargaretkaBackupError.invalidFilename(asset.filename)
            }
            let directory: URL
            switch asset.kind {
            case .audio:
                directory = try AudioStorage.applicationSupportDirectory(create: true)
            case .offlineBreviaryImage:
                directory = OfflineBreviaryStore.imageDirectory
            }
            let destination = directory.appendingPathComponent(asset.filename)
            try asset.data.write(to: destination, options: .atomic)
            result[assetMapKey(asset.kind, asset.filename)] = asset.filename
        }
        return result
    }

    private static func validateAssetFilenames(_ assets: [MargaretkaBackupAsset]) throws {
        for asset in assets where asset.filename != URL(fileURLWithPath: asset.filename).lastPathComponent {
            throw MargaretkaBackupError.invalidFilename(asset.filename)
        }
    }

    private struct ConflictDecision {
        var existingID: UUID
        var resolution: BackupConflictResolution
    }

    private static func conflictLookup(
        _ conflicts: [BackupImportConflict],
        resolutions: [UUID: BackupConflictResolution],
        importedID: (BackupImportConflict.EntityKind) -> UUID?
    ) -> [UUID: ConflictDecision] {
        var result: [UUID: ConflictDecision] = [:]
        for conflict in conflicts {
            guard let imported = importedID(conflict.kind), let resolution = resolutions[conflict.id] else { continue }
            let existing: UUID
            switch conflict.kind {
            case .prayer(let id, _), .target(let id, _), .breviary(let id, _): existing = id
            }
            result[imported] = ConflictDecision(existingID: existing, resolution: resolution)
        }
        return result
    }

    private static func prayerConflict(existing: Prayer, imported: Prayer) -> BackupImportConflict {
        BackupImportConflict(
            title: "Czy to ta sama modlitwa?",
            existingSummary: "\(existing.name)\n\n\(existing.text.prefix(600))",
            importedSummary: "\(imported.name)\n\n\(imported.text.prefix(600))",
            kind: .prayer(existingID: existing.id, importedID: imported.id)
        )
    }

    private static func targetConflict(existing: Priest, imported: Priest) -> BackupImportConflict {
        BackupImportConflict(
            title: "Czy to ta sama osoba lub modlitwa złożona?",
            existingSummary: "\(existing.category.displayName): \(existing.displayName)\nGrupy: \(existing.assignedPrayerGroups.count)",
            importedSummary: "\(imported.category.displayName): \(imported.displayName)\nGrupy: \(imported.assignedPrayerGroups.count)",
            kind: .target(existingID: existing.id, importedID: imported.id)
        )
    }

    private static func prayersAreEquivalent(_ lhs: Prayer, _ rhs: Prayer) -> Bool {
        normalized(lhs.name) == normalized(rhs.name)
            && normalized(lhs.text) == normalized(rhs.text)
            && lhs.content == rhs.content
    }

    private static func targetsAreEquivalent(_ lhs: Priest, _ rhs: Priest) -> Bool {
        lhs.category == rhs.category
            && normalized(lhs.displayName) == normalized(rhs.displayName)
            && lhs.photoData == rhs.photoData
            && lhs.photoAssetID == rhs.photoAssetID
            && lhs.photoUpdatedAt == rhs.photoUpdatedAt
            && lhs.photoScale == rhs.photoScale
            && lhs.photoOffsetX == rhs.photoOffsetX
            && lhs.photoOffsetY == rhs.photoOffsetY
            && lhs.photoPlacements == rhs.photoPlacements
            && lhs.assignedPrayerGroups == rhs.assignedPrayerGroups
            && lhs.schedule == rhs.schedule
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func officeFingerprints(_ day: OfflineBreviaryDay) -> [String] {
        var fingerprints = day.offices.map { "\($0.key.rawValue):\($0.contentFingerprint)" }
        if let biography = day.saintBiography {
            fingerprints.append("saint:\(biography.title):\(biography.text)")
        }
        return fingerprints.sorted()
    }

    private static func breviarySummary(_ day: OfflineBreviaryDay) -> String {
        let officeNames = day.offices.map(\.title).joined(separator: ", ")
        let saint = day.saintBiography == nil ? "" : "\nŚwięty dnia"
        return "\(day.celebrationName ?? day.sourceTitle)\n\(officeNames)\(saint)"
    }

    private static func prayer(_ source: Prayer, replacingIDWith id: UUID) -> Prayer {
        Prayer(
            id: id,
            name: source.name,
            text: source.text,
            symbol: source.symbol,
            audioFilename: source.audioFilename,
            audioSource: source.audioSource,
            timestampedLines: source.timestampedLines,
            content: source.content
        )
    }

    private static func remapping(_ target: Priest, prayerIDs: [UUID: UUID]) -> Priest {
        var result = target
        result.assignedPrayerGroups = target.assignedPrayerGroups.map { remapping($0, prayerIDs: prayerIDs) }
        return result
    }

    private static func remapping(_ group: AssignedPrayerGroup, prayerIDs: [UUID: UUID]) -> AssignedPrayerGroup {
        let items = group.items.map { item -> AssignedPrayerItem in
            if case .prayer(let id) = item { return .prayer(prayerIDs[id] ?? id) }
            return item
        }
        return AssignedPrayerGroup(
            id: group.id,
            items: items,
            repeatCount: group.repeatCount,
            subgroups: group.subgroups.map { remapping($0, prayerIDs: prayerIDs) }
        )
    }

    private static func remapping(
        _ session: PrayerSession,
        prayerIDs: [UUID: UUID],
        targetIDs: [UUID: UUID]
    ) -> PrayerSession {
        PrayerSession(
            id: session.id,
            targetId: session.targetId.map { targetIDs[$0] ?? $0 },
            targetName: session.targetName,
            targetCategory: session.targetCategory,
            prayerIds: session.prayerIds.map { prayerIDs[$0] ?? $0 },
            prayerNames: session.prayerNames,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            duration: session.duration,
            totalSubprayerCount: session.totalSubprayerCount,
            completedSubprayerCount: session.completedSubprayerCount,
            completed: session.completed,
            completion: session.completion
        )
    }

    private static func remappingImages(
        _ source: OfflineBreviaryDay,
        filenameMap: [String: String]
    ) -> OfflineBreviaryDay {
        var result = source
        result.offices = source.offices.map { office in
            var updated = office
            if let filename = office.imageFilename {
                updated.imageFilename = filenameMap[assetMapKey(.offlineBreviaryImage, filename)] ?? filename
            }
            return updated
        }
        return result
    }

    private static func day(
        _ source: OfflineBreviaryDay,
        replacingIDWith id: UUID,
        variantSuffix: String = ""
    ) -> OfflineBreviaryDay {
        OfflineBreviaryDay(
            id: id,
            date: source.date,
            variantIdentifier: source.variantIdentifier + variantSuffix,
            variantName: source.variantName + variantSuffix,
            celebrationName: source.celebrationName,
            liturgicalColor: source.liturgicalColor,
            saintBiography: source.saintBiography,
            offices: source.offices,
            sourceImportID: source.sourceImportID,
            sourceIdentifier: source.sourceIdentifier,
            sourceTitle: source.sourceTitle,
            importedAt: source.importedAt
        )
    }

    private static func assetMapKey(_ kind: MargaretkaBackupAsset.Kind, _ filename: String) -> String {
        "\(kind.rawValue)|\(filename)"
    }
}

enum DataTransferRoute {
    case overview
    case export
    case backup
    case restore
    case sharePrayers
}

struct DataTransferView: View {
    private enum ImportIntent {
        case mergeData
        case restoreBackup
    }

    @ObservedObject var targetStore: PriestStore
    var initialRoute: DataTransferRoute = .overview
    @EnvironmentObject private var prayerStore: PrayerStore
    @EnvironmentObject private var offlineStore: OfflineBreviaryStore
    @EnvironmentObject private var scheduleData: ScheduleData<Priest>

    @State private var isImporting = false
    @State private var importIntent: ImportIntent = .mergeData
    @State private var showingExportSelection = false
    @State private var shareURL: URL?
    @State private var importPlan: BackupImportPlan?
    @State private var backupToRestore: MargaretkaBackup?
    @State private var resolutions: [UUID: BackupConflictResolution] = [:]
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var epubProgress: BrewiarzEPUBImportProgress?

    var body: some View {
        List {
            Section("Brewiarz offline") {
                NavigationLink("Zarządzaj zapisanymi dniami") {
                    OfflineBreviaryManagerView()
                }
            }

            Section("Import i eksport danych") {
                Button {
                    showingExportSelection = true
                } label: {
                    Label("Eksportuj wybrane dane", systemImage: "square.and.arrow.up")
                }

                Button {
                    importIntent = .mergeData
                    isImporting = true
                } label: {
                    Label("Importuj i połącz dane", systemImage: "square.and.arrow.down")
                }

                Text("Eksport może zawierać pojedynczą modlitwę, konkretną osobę lub księdza albo wybraną godzinę brewiarza. Nie zawiera historii, statystyk ani ustawień. Import JSON zachowuje obecne dane, scala dokładne odpowiedniki i pyta o podejrzane podobieństwa. Można tu również importować EPUB z brewiarz.pl.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Pełna kopia zapasowa") {
                Button {
                    exportArchive(purpose: .fullBackup)
                } label: {
                    Label("Utwórz i udostępnij kopię", systemImage: "externaldrive.badge.plus")
                }

                Button {
                    importIntent = .restoreBackup
                    isImporting = true
                } label: {
                    Label("Przywróć pełną kopię", systemImage: "arrow.counterclockwise.icloud")
                }

                Text("Kopia zawiera wszystkie modlitwy pojedyncze i złożone, osoby, księży, harmonogramy, wykonania i statystyki, zdjęcia, audio, brewiarz offline, jego obrazy oraz ustawienia widoku. Przywrócenie zastępuje aktualny stan aplikacji stanem z kopii.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Import i eksport")
        .onAppear {
            switch initialRoute {
            case .overview:
                break
            case .export, .sharePrayers:
                showingExportSelection = true
            case .backup:
                exportArchive(purpose: .fullBackup)
            case .restore:
                importIntent = .restoreBackup
                isImporting = true
            }
        }
        .disabled(epubProgress != nil)
        .overlay {
            if let progress = epubProgress {
                EPUBImportProgressView(progress: progress)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .epub]) { result in
            do {
                let url = try result.get()
                if importIntent == .restoreBackup, url.pathExtension.lowercased() != "json" {
                    throw MargaretkaBackupError.notJSONBackup
                }
                if url.pathExtension.lowercased() == "epub" {
                    importEPUB(url)
                    return
                } else {
                    prepareImport(try MargaretkaBackupService.decode(from: url))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingExportSelection) {
            ExportSelectionView(
                prayers: prayerStore.prayers,
                targets: targetStore.priests,
                offlineDays: offlineStore.days
            ) { selection in
                showingExportSelection = false
                exportArchive(purpose: .dataTransfer, selection: selection)
            }
        }
        .sheet(item: $shareURL) { url in
            ActivityShareView(items: [url])
        }
        .sheet(isPresented: Binding(
            get: { importPlan?.conflicts.isEmpty == false },
            set: { if !$0 { importPlan = nil } }
        )) {
            if let plan = importPlan {
                BackupConflictResolutionView(
                    conflicts: plan.conflicts,
                    resolutions: $resolutions,
                    onCancel: { importPlan = nil },
                    onApply: { applyImport(plan) }
                )
            }
        }
        .confirmationDialog(
            "Przywrócić pełną kopię?",
            isPresented: Binding(
                get: { backupToRestore != nil },
                set: { if !$0 { backupToRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Zastąp aktualny stan", role: .destructive) {
                restoreFullBackup()
            }
            Button("Anuluj", role: .cancel) {
                backupToRestore = nil
            }
        } message: {
            if let backup = backupToRestore {
                Text("Aktualne dane zostaną zastąpione stanem z \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)). Tej operacji nie można cofnąć bez innej kopii zapasowej.")
            }
        }
        .alert("Nie udało się", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Nieznany błąd")
        }
    }

    private func exportArchive(
        purpose: MargaretkaArchivePurpose,
        selection: MargaretkaExportSelection = .allCurrentData
    ) {
        do {
            shareURL = try MargaretkaBackupService.export(
                prayers: prayerStore.prayers,
                targets: targetStore.priests,
                offlineDays: offlineStore.days,
                purpose: purpose,
                selection: selection
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importEPUB(_ url: URL) {
        epubProgress = BrewiarzEPUBImportProgress(
            completedDocuments: 0,
            totalDocuments: 0,
            elapsed: 0
        )
        message = nil
        Task { @MainActor in
            do {
                let imported = try await BrewiarzEPUBImporter.importEPUB(
                    from: url,
                    preferredVariantOrder: BreviaryVariantPreferences.load()
                ) { progress in
                    withAnimation(.linear(duration: 0.2)) {
                        epubProgress = progress
                    }
                }
                epubProgress = nil
                let retained = OfflineBreviaryStore.removingExpired(from: imported.days, referenceDate: .now)
                let expiredCount = imported.days.count - retained.count
                guard !retained.isEmpty else {
                    message = "EPUB zawiera tylko wygasłe dni (pominięto: \(expiredCount))."
                    return
                }
                prayerStore.ensureDefaultPrayers()
                let breviaryTargets = BreviaryPrayerTargetFactory.missingTargets(
                    for: retained,
                    prayers: prayerStore.prayers,
                    existingTargets: targetStore.priests
                )
                prepareImport(MargaretkaBackup(
                    schemaVersion: MargaretkaBackup.currentSchemaVersion,
                    exportedAt: .now,
                    purpose: .dataTransfer,
                    preferences: nil,
                    prayers: [],
                    targets: breviaryTargets,
                    sessions: [],
                    offlineBreviaryDays: retained,
                    assets: []
                ))
            } catch {
                epubProgress = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareImport(_ backup: MargaretkaBackup) {
        if importIntent == .restoreBackup {
            backupToRestore = backup
            return
        }
        let plan = MargaretkaBackupService.makeImportPlan(
            backup: backup,
            prayers: prayerStore.prayers,
            targets: targetStore.priests,
            offlineDays: offlineStore.days
        )
        importPlan = plan
        resolutions = [:]
        if plan.conflicts.isEmpty { applyImport(plan) }
    }

    private func restoreFullBackup() {
        guard let backup = backupToRestore else { return }
        do {
            let report = try MargaretkaBackupService.restoreExactly(
                backup: backup,
                prayerStore: prayerStore,
                targetStore: targetStore,
                offlineStore: offlineStore,
                scheduleData: scheduleData
            )
            message = report.summary
            backupToRestore = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyImport(_ plan: BackupImportPlan) {
        guard plan.conflicts.allSatisfy({ resolutions[$0.id] != nil }) else { return }
        do {
            let report = try MargaretkaBackupService.apply(
                plan: plan,
                resolutions: resolutions,
                prayerStore: prayerStore,
                targetStore: targetStore,
                offlineStore: offlineStore
            )
            message = report.summary
            importPlan = nil
            scheduleData.items = targetStore.priests
            scheduleData.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ExportSelectionView: View {
    let prayers: [Prayer]
    let targets: [Priest]
    let offlineDays: [OfflineBreviaryDay]
    let onSelect: (MargaretkaExportSelection) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    exportButton("Wszystkie dane bieżące", symbol: "tray.full", selection: .allCurrentData)
                } footer: {
                    Text("Obejmuje modlitwy, osoby, księży, modlitwy złożone i brewiarz offline, ale bez historii, statystyk i ustawień.")
                }

                if !availableOfficeKeys.isEmpty || offlineDays.contains(where: { $0.saintBiography != nil }) {
                    Section("Brewiarz offline") {
                        ForEach(availableOfficeKeys) { key in
                            exportButton(
                                "Wszystkie: \(key.displayName)",
                                symbol: symbol(for: key),
                                selection: .breviaryOffice(key)
                            )
                        }
                        if offlineDays.contains(where: { $0.saintBiography != nil }) {
                            exportButton(
                                "Wszystkie życiorysy świętych",
                                symbol: "person.crop.circle.badge.checkmark",
                                selection: .saintBiographies
                            )
                        }
                    }
                }

                ForEach(PrayerTargetCategory.allCases) { category in
                    let categoryTargets = sortedTargets.filter { $0.category == category }
                    if !categoryTargets.isEmpty {
                        Section(category.displayName) {
                            ForEach(categoryTargets) { target in
                                exportButton(
                                    target.displayName,
                                    symbol: targetSymbol(for: category),
                                    selection: .target(target.id)
                                )
                            }
                        }
                    }
                }

                if !textPrayers.isEmpty {
                    Section("Modlitwy pojedyncze") {
                        ForEach(textPrayers) { prayer in
                            exportButton(
                                prayer.name,
                                symbol: prayer.symbol,
                                selection: .prayer(prayer.id)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Co wyeksportować?")
            .safeNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
        }
    }

    private var availableOfficeKeys: [BrewiarzPrayerKey] {
        let keys = Set(offlineDays.flatMap(\.offices).map(\.key))
        return BrewiarzPrayerKey.allCases.filter(keys.contains)
    }

    private var sortedTargets: [Priest] {
        targets.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var textPrayers: [Prayer] {
        prayers.filter {
            if case .text = $0.content { return true }
            return false
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func exportButton(
        _ title: String,
        symbol: String,
        selection: MargaretkaExportSelection
    ) -> some View {
        Button {
            onSelect(selection)
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    private func targetSymbol(for category: PrayerTargetCategory) -> String {
        switch category {
        case .priest: return "person.crop.rectangle.stack"
        case .person: return "person.crop.circle"
        case .prayer: return "square.stack.3d.up"
        }
    }

    private func symbol(for key: BrewiarzPrayerKey) -> String {
        switch key {
        case .msza: return "cross.case"
        case .wezwanie: return "bell"
        case .godzinaCzytan: return "book.pages"
        case .jutrznia: return "sunrise"
        case .modlitwaPrzedpoludniowa: return "sun.min"
        case .modlitwaPoludniowa: return "sun.max"
        case .modlitwaPopoludniowa: return "sun.haze"
        case .nieszpory: return "sunset"
        case .kompleta: return "moon.stars"
        }
    }
}

private struct EPUBImportProgressView: View {
    let progress: BrewiarzEPUBImportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Importowanie brewiarza")
                        .font(.headline)
                }
                if progress.totalDocuments > 0 {
                    ProgressView(value: progress.fractionCompleted)
                        .animation(.linear(duration: 0.2), value: progress.fractionCompleted)
                    Text("Dokument \(progress.completedDocuments) z \(progress.totalDocuments)")
                        .font(.subheadline.monospacedDigit())
                    if let remaining = progress.estimatedRemaining, remaining > 0 {
                        Text("Pozostało około \(formattedDuration(remaining))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if progress.completedDocuments == 0 {
                        Text("Obliczanie czasu…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Odczytywanie archiwum…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 18)
        }
        .transition(.opacity)
        .shadow(radius: 18)
        .padding()
        .accessibilityElement(children: .combine)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = max(1, Int(duration.rounded(.up)))
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes) min" : "\(minutes) min \(remainder) s"
    }
}

private struct BackupConflictResolutionView: View {
    let conflicts: [BackupImportConflict]
    @Binding var resolutions: [UUID: BackupConflictResolution]
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Podejrzane podobieństwa wymagają decyzji. Porównaj obecną i importowaną wersję.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(conflicts) { conflict in
                    Section(conflict.title) {
                        HStack(alignment: .top, spacing: 12) {
                            comparisonColumn(title: "OBECNE", text: conflict.existingSummary)
                            Divider()
                            comparisonColumn(title: "IMPORT", text: conflict.importedSummary)
                        }
                        Picker("Decyzja", selection: Binding(
                            get: { resolutions[conflict.id] },
                            set: { resolutions[conflict.id] = $0 }
                        )) {
                            Text("Wybierz…").tag(nil as BackupConflictResolution?)
                            ForEach(BackupConflictResolution.allCases) { resolution in
                                Text(resolution.title).tag(Optional(resolution))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Porównaj dane")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importuj", action: onApply)
                        .disabled(conflicts.contains { resolutions[$0.id] == nil })
                }
            }
        }
    }

    private func comparisonColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(text).font(.caption).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if !os(macOS)
private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
private struct ActivityShareView: View {
    let items: [Any]

    var body: some View {
        Text("Udostępnianie jest dostępne z poziomu Findera.")
            .padding()
    }
}
#endif

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private extension View {
    @ViewBuilder
    func safeNavigationBarTitleDisplayModeInline() -> some View {
#if os(macOS)
        self
#else
        navigationBarTitleDisplayMode(.inline)
#endif
    }
}
