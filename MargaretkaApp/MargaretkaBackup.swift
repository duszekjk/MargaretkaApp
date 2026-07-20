import Foundation
import SwiftUI
internal import UniformTypeIdentifiers
import UIKit

struct MargaretkaBackup: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var prayers: [Prayer]
    var targets: [Priest]
    var sessions: [PrayerSession]
    var offlineBreviaryDays: [OfflineBreviaryDay]
    var assets: [MargaretkaBackupAsset]
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
    let breviaryDaysAdded: Int

    var summary: String {
        "Dodano: \(prayersAdded) modlitw, \(targetsAdded) osób lub modlitw złożonych, \(sessionsAdded) wpisów historii i \(breviaryDaysAdded) dni brewiarza."
    }
}

enum MargaretkaBackupService {
    static func export(
        prayers: [Prayer],
        targets: [Priest],
        offlineDays: [OfflineBreviaryDay]
    ) throws -> URL {
        let sessions: [PrayerSession] = LocalDatabase.shared.load(from: PrayerSessionStore.saveKey)
        let backup = MargaretkaBackup(
            schemaVersion: MargaretkaBackup.currentSchemaVersion,
            exportedAt: .now,
            prayers: prayers,
            targets: targets,
            sessions: sessions,
            offlineBreviaryDays: offlineDays,
            assets: collectAssets(prayers: prayers, offlineDays: offlineDays)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(backup)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let filename = "Margaretka_\(formatter.string(from: .now)).json"
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
        if sessionsAdded > 0 {
            NotificationCenter.default.post(name: .prayerSessionsChanged, object: nil)
        }

        var days = offlineStore.days
        let initialDayCount = days.count
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

        return BackupImportReport(
            prayersAdded: prayersAdded,
            targetsAdded: targetsAdded,
            sessionsAdded: sessionsAdded,
            breviaryDaysAdded: max(0, offlineStore.days.count - initialDayCount)
        )
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
            && lhs.assignedPrayerGroups == rhs.assignedPrayerGroups
            && lhs.schedule == rhs.schedule
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func officeFingerprints(_ day: OfflineBreviaryDay) -> [String] {
        day.offices.map { "\($0.key.rawValue):\($0.contentFingerprint)" }.sorted()
    }

    private static func breviarySummary(_ day: OfflineBreviaryDay) -> String {
        let officeNames = day.offices.map(\.title).joined(separator: ", ")
        return "\(day.celebrationName ?? day.sourceTitle)\n\(officeNames)"
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

struct DataTransferView: View {
    @ObservedObject var targetStore: PriestStore
    @EnvironmentObject private var prayerStore: PrayerStore
    @EnvironmentObject private var offlineStore: OfflineBreviaryStore

    @State private var isImporting = false
    @State private var shareURL: URL?
    @State private var importPlan: BackupImportPlan?
    @State private var resolutions: [UUID: BackupConflictResolution] = [:]
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Pełna kopia JSON") {
                Button {
                    exportBackup()
                } label: {
                    Label("Eksportuj i udostępnij", systemImage: "square.and.arrow.up")
                }

                Button {
                    isImporting = true
                } label: {
                    Label("Importuj kopię", systemImage: "square.and.arrow.down")
                }

                Text("Import przyjmuje pełną kopię JSON albo eksport EPUB z brewiarz.pl. Kopia JSON obejmuje modlitwy pojedyncze i złożone, osoby i księży, harmonogramy, historię, zdjęcia, audio oraz zapisany brewiarz offline.")
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
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .epub]) { result in
            do {
                let url = try result.get()
                let backup: MargaretkaBackup
                if url.pathExtension.lowercased() == "epub" {
                    let imported = try BrewiarzEPUBImporter.importEPUB(from: url)
                    let retained = OfflineBreviaryStore.removingExpired(from: imported.days, referenceDate: .now)
                    let expiredCount = imported.days.count - retained.count
                    backup = MargaretkaBackup(
                        schemaVersion: MargaretkaBackup.currentSchemaVersion,
                        exportedAt: .now,
                        prayers: [],
                        targets: [],
                        sessions: [],
                        offlineBreviaryDays: retained,
                        assets: []
                    )
                    if retained.isEmpty {
                        message = "EPUB zawiera tylko wygasłe dni (pominięto: \(expiredCount))."
                        return
                    }
                } else {
                    backup = try MargaretkaBackupService.decode(from: url)
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
            } catch {
                errorMessage = error.localizedDescription
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
        .alert("Nie udało się", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Nieznany błąd")
        }
    }

    private func exportBackup() {
        do {
            shareURL = try MargaretkaBackupService.export(
                prayers: prayerStore.prayers,
                targets: targetStore.priests,
                offlineDays: offlineStore.days
            )
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
        } catch {
            errorMessage = error.localizedDescription
        }
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

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
