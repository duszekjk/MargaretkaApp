//
//  PrayerHistory.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI
internal import Combine

#if os(macOS)
private struct MacSheetDismissButton: ToolbarContent {
    @Environment(\.dismiss) private var dismiss

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Zamknij") { dismiss() }
        }
    }
}
#endif

struct PrayerHistory: Identifiable {
    let id = UUID()
    let date: Date
    let priestId: UUID?
    let prayerIds: [UUID]
    let completed: Bool
}


class PrayerStore: ObservableObject {
    @Published var prayers: [Prayer] = [] {
        didSet { save() }
    }

    private let key = "stored_prayers"
    private let legacyDefaultsKey = "stored_prayers"
    private var pendingChangedIDs = Set<String>()
    private var pendingDeletedIDs = Set<String>()

    init() {
        let start = CFAbsoluteTimeGetCurrent()
        load()
        ensureDefaultPrayers()
        AudioStorage.removeOrphanedFiles(referencedBy: prayers)
        let duration = CFAbsoluteTimeGetCurrent() - start
        print("PrayerStore init in \(String(format: "%.3f", duration))s")
    }

    private func load() {
        let stored: [Prayer] = LocalDatabase.shared.load(from: key)
        if !stored.isEmpty {
            self.prayers = Self.deduplicatingBreviaryPrayers(stored)
            return
        }

        if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode([Prayer].self, from: data) {
            self.prayers = Self.deduplicatingBreviaryPrayers(decoded)
            LocalDatabase.shared.save(decoded, as: key)
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        }
    }

    private func save() {
        let changed = pendingChangedIDs.isEmpty
            ? Set(prayers.map { $0.id.uuidString.lowercased() })
            : pendingChangedIDs
        let deleted = pendingDeletedIDs
        pendingChangedIDs.removeAll()
        pendingDeletedIDs.removeAll()
        LocalDatabase.shared.save(prayers, as: key, changedIDs: changed, deletedIDs: deleted)
    }

    func ensureDefaultPrayers() {
        let deduplicated = Self.deduplicatingBreviaryPrayers(prayers)
        let merged = Self.mergingDefaultPrayers(into: deduplicated)
        if merged != prayers {
            prayers = merged
            save()
        }
    }

    static func deduplicatingBreviaryPrayers(_ prayers: [Prayer]) -> [Prayer] {
        var seenIDs = Set<UUID>()
        var seenBreviaryKeys = Set<BrewiarzPrayerKey>()
        return prayers.filter { prayer in
            guard seenIDs.insert(prayer.id).inserted else { return false }
            if case .brewiarz(let key) = prayer.content {
                return seenBreviaryKeys.insert(key).inserted
            }
            return true
        }
    }

    static func mergingDefaultPrayers(into existing: [Prayer]) -> [Prayer] {
        let existingNames = Set(existing.map { $0.name })
        let templates = Array(prayersTemplate.values)
        var merged = existing
        for template in templates {
            let alreadyExists: Bool
            switch template.content {
            case .brewiarz(let key):
                alreadyExists = merged.contains {
                    if case .brewiarz(let existingKey) = $0.content {
                        return existingKey == key
                    }
                    return false
                }
            case .saintBiography:
                alreadyExists = merged.contains { $0.content == .saintBiography }
            case .text:
                alreadyExists = existingNames.contains(template.name)
            }
            if !alreadyExists { merged.append(template) }
        }
        return merged
    }

    func addOrUpdate(_ prayer: Prayer) {
        pendingChangedIDs.insert(prayer.id.uuidString.lowercased())
        if let index = prayers.firstIndex(where: { $0.id == prayer.id }) {
            let replacedAudio = prayers[index].audioFilename
            prayers[index] = prayer
            if replacedAudio != prayer.audioFilename {
                AudioStorage.removeFile(named: replacedAudio)
            }
        } else {
            prayers.append(prayer)
        }
    }

    func delete(at offsets: IndexSet) {
        pendingDeletedIDs.formUnion(offsets.compactMap { prayers[$0].id.uuidString.lowercased() })
        let removedAudio = offsets.compactMap { prayers[$0].audioFilename }
        prayers.remove(atOffsets: offsets)
        removedAudio.forEach(AudioStorage.removeFile(named:))
    }
}

struct HomeView: View {
    @EnvironmentObject var priestStore: PriestStore
    @EnvironmentObject var prayerStore: PrayerStore
    @EnvironmentObject var scheduleData: ScheduleData<Priest>
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject var offlineStore: OfflineBreviaryStore
    
    
    @State var showSettings: Bool = false
    @State var showEditor: Bool = false
    @State var showOsoby: Bool = false
    @State var showCzymJest: Bool = false
    @State var showJakSie: Bool = false
    @State private var didLoadInitialData = false
    @State private var showImport = false
    @State private var dataTransferRoute: DataTransferRoute = .overview
    @State private var pendingImportFile: URL?
    @State private var showStatistics = false
    @State private var showSyncSettings = false
    @State private var menuTargetCategory: PrayerTargetCategory?
#if os(macOS)
    @State private var newTargetCategory: PrayerTargetCategory?
    @State private var editingTarget: Priest?
#endif
    @AppStorage("prayerCompactView") private var prayerCompactView = false

    var body: some View {
        PrayerFlowView(showSettings: $showSettings, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie)
            .environmentObject(priestStore)
#if !os(macOS)
            .toolbar {
                NavigationLink(destination: SettingsMenuView(priestStore: priestStore, availablePrayers: $prayerStore.prayers, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie, menuTargetCategory: $menuTargetCategory),
                               isActive: $showSettings) {
                    Image(systemName: "gear")
                }
            }
#endif
            .onAppear {
                let now = CFAbsoluteTimeGetCurrent()
                print("HomeView onAppear at \(String(format: "%.3f", now))")
#if os(macOS)
                MacMenuCatalog.update(scheduleData.items)
#endif
            }
#if os(macOS)
            .onChange(of: scheduleData.items) { _, items in
                MacMenuCatalog.update(items)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsMenuView(
                        priestStore: priestStore,
                        availablePrayers: $prayerStore.prayers,
                        showEditor: $showEditor,
                        showOsoby: $showOsoby,
                        showCzymJest: $showCzymJest,
                        showJakSie: $showJakSie,
                        menuTargetCategory: $menuTargetCategory
                    )
                }
#if os(macOS)
                .toolbar { MacSheetDismissButton() }
#endif
                .frame(minWidth: 520, minHeight: 480)
            }
#endif
            .sheet(isPresented: $showImport) {
                NavigationStack {
                    DataTransferView(targetStore: priestStore, initialRoute: dataTransferRoute, initialFileURL: pendingImportFile)
                }
                .onDisappear { pendingImportFile = nil }
            }
            .sheet(isPresented: $showStatistics) {
                NavigationStack {
                    StatsView()
                }
#if os(macOS)
                .toolbar { MacSheetDismissButton() }
#endif
            }
            .sheet(isPresented: $showSyncSettings) {
                NavigationStack {
                    SyncSettingsView()
                }
#if os(macOS)
                .toolbar { MacSheetDismissButton() }
#endif
            }
#if os(macOS)
            .sheet(item: $newTargetCategory) { category in
                MacNewTargetEditorSheet(
                    store: priestStore,
                    availablePrayers: $prayerStore.prayers,
                    category: category
                )
            }
            .sheet(item: $editingTarget) { target in
                MacNewTargetEditorSheet(
                    store: priestStore,
                    availablePrayers: $prayerStore.prayers,
                    category: target.category,
                    existing: target
                )
            }
#endif
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaSettings)) { _ in
                showSettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaImport)) { notification in
                showSettings = false
                switch notification.object as? String {
                case "import": dataTransferRoute = .importData
                case "export": dataTransferRoute = .export
                case "backup": dataTransferRoute = .backup
                case "restore": dataTransferRoute = .restore
                case "share": dataTransferRoute = .sharePrayers
                default: dataTransferRoute = .overview
                }
                showImport = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaImportFile)) { notification in
                guard let url = notification.object as? URL else { return }
                showSettings = false
                dataTransferRoute = .overview
                pendingImportFile = url
                showImport = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaStatistics)) { _ in
                showSettings = false
                showImport = false
                showStatistics = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaNewPerson)) { notification in
                let category = (notification.object as? PrayerTargetCategory) ?? .person
#if os(macOS)
                showSettings = false
                newTargetCategory = category
#else
                showSettings = true
                DispatchQueue.main.async {
                    menuTargetCategory = category
                }
#endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaEditTarget)) { notification in
#if os(macOS)
                guard let id = notification.object as? UUID else { return }
                editingTarget = priestStore.priests.first(where: { $0.id == id })
                    ?? scheduleData.items.first(where: { $0.id == id })
#endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaHowTo)) { _ in
                showSettings = true
                DispatchQueue.main.async { showJakSie = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaAbout)) { _ in
                showSettings = true
                DispatchQueue.main.async { showCzymJest = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaSyncSettings)) { _ in
                showSettings = false
                showSyncSettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaPrayerList)) { _ in
                showSettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaToggleCompact)) { _ in
                prayerCompactView.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .margaretkaSync)) { _ in
                Task {
                    await syncService.synchronize(
                        prayerStore: prayerStore,
                        targetStore: priestStore,
                        offlineStore: offlineStore
                    )
                }
            }
            .task {
                loadInitialData()
            }
    }

    private func loadInitialData() {
        guard !didLoadInitialData else { return }
        didLoadInitialData = true
        let loadId = UUID().uuidString.prefix(6)
        let scheduledAt = CFAbsoluteTimeGetCurrent()
        let prayersSnapshot = prayerStore.prayers
        let templatePrayers = Array(prayersTemplate.values)

        Task.detached(priority: .utility) {
            let taskStart = CFAbsoluteTimeGetCurrent()
            let scheduleDelay = taskStart - scheduledAt
            let overallStart = CFAbsoluteTimeGetCurrent()
            let templatesStart = CFAbsoluteTimeGetCurrent()
            print("HomeView loadInitialData[\(loadId)] templates start \(String(format: "%.3f", templatesStart))")
            let loadedPriests = Priest.loadWithTemplates(using: prayersSnapshot)
            let templatesEnd = CFAbsoluteTimeGetCurrent()
            let templatesDuration = templatesEnd - templatesStart
            print("HomeView loadInitialData[\(loadId)] templates end \(String(format: "%.3f", templatesEnd)) elapsed \(String(format: "%.3f", templatesDuration))s")

            let mergeStart = CFAbsoluteTimeGetCurrent()
            let existingPrayerNames = Set(prayersSnapshot.map { $0.name })
            var mergedPrayers = prayersSnapshot
            for template in templatePrayers where !existingPrayerNames.contains(template.name) {
                mergedPrayers.append(template)
            }
            let mergeDuration = CFAbsoluteTimeGetCurrent() - mergeStart

            let mainStart = CFAbsoluteTimeGetCurrent()
            await MainActor.run {
                if priestStore.priests != loadedPriests {
                    priestStore.priests = loadedPriests
                }
                // The schedule is the source used by PrayerFlowView's picker.
                // On a new installation PriestStore can already contain the
                // built-in targets while ScheduleData is still empty.
                if scheduleData.items != loadedPriests {
                    scheduleData.items = loadedPriests
                    scheduleData.save()
                }
                if mergedPrayers != prayersSnapshot {
                    prayerStore.prayers = mergedPrayers
                }
            }
            let mainDuration = CFAbsoluteTimeGetCurrent() - mainStart
            let overallDuration = CFAbsoluteTimeGetCurrent() - overallStart

            print("HomeView loadInitialData[\(loadId)] schedule delay \(String(format: "%.3f", scheduleDelay))s")
            print("HomeView loadInitialData[\(loadId)] in \(String(format: "%.3f", overallDuration))s")
            print("HomeView loadInitialData[\(loadId)] breakdown: templates \(String(format: "%.3f", templatesDuration))s, merge \(String(format: "%.3f", mergeDuration))s, main \(String(format: "%.3f", mainDuration))s")
        }
    }
}
