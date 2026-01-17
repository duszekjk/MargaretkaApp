//
//  PrayerHistory.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI
internal import Combine

struct PrayerHistory: Identifiable {
    let id = UUID()
    let date: Date
    let priestId: UUID?
    let prayerIds: [UUID]
    let completed: Bool
}


class PrayerStore: ObservableObject {
    @Published var prayers: [Prayer] = [] {
        didSet { saveAsync() }
    }

    private let key = "stored_prayers"
    private let legacyDefaultsKey = "stored_prayers"
    private let saveQueue = DispatchQueue(label: "PrayerStore.save", qos: .utility)
    private var isLoading = false

    init() {
        loadAsync()
    }

    private func loadAsync() {
        guard !isLoading else { return }
        isLoading = true
        let start = CFAbsoluteTimeGetCurrent()
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = self.loadFromDisk()
            let merged = self.mergeDefaultPrayers(into: loaded)
            DispatchQueue.main.async {
                self.prayers = merged
                self.isLoading = false
                let duration = CFAbsoluteTimeGetCurrent() - start
                print("PrayerStore load in \(String(format: "%.3f", duration))s")
            }
        }
    }

    private func loadFromDisk() -> [Prayer] {
        let stored: [Prayer] = LocalDatabase.shared.load(from: key)
        if !stored.isEmpty {
            return stored
        }

        if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode([Prayer].self, from: data) {
            LocalDatabase.shared.save(decoded, as: key)
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            return decoded
        }
        return []
    }

    private func saveAsync() {
        let snapshot = prayers
        saveQueue.async {
            LocalDatabase.shared.save(snapshot, as: self.key)
        }
    }

    private func mergeDefaultPrayers(into existing: [Prayer]) -> [Prayer] {
        let existingNames = Set(existing.map { $0.name })
        let templates = Array(prayersTemplate.values)
        var merged = existing
        for template in templates where !existingNames.contains(template.name) {
            merged.append(template)
        }
        return merged
    }

    func addOrUpdate(_ prayer: Prayer) {
        if let index = prayers.firstIndex(where: { $0.id == prayer.id }) {
            prayers[index] = prayer
        } else {
            prayers.append(prayer)
        }
    }

    func delete(at offsets: IndexSet) {
        prayers.remove(atOffsets: offsets)
    }
}

struct HomeView: View {
    @StateObject var priestStore = PriestStore()
    @EnvironmentObject var prayerStore: PrayerStore
    
    
    @State var showSettings: Bool = false
    @State var showEditor: Bool = false
    @State var showOsoby: Bool = false
    @State var showCzymJest: Bool = false
    @State var showJakSie: Bool = false
    @State private var didLoadInitialData = false

    var body: some View {
        PrayerFlowView(showSettings: $showSettings, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie)
            .toolbar {
                NavigationLink(destination: SettingsMenuView(priestStore: priestStore, availablePrayers: $prayerStore.prayers, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie),
                               isActive: $showSettings) {
                    Image(systemName: "gear")
                }
            }
            .onAppear {
                let now = CFAbsoluteTimeGetCurrent()
                print("HomeView onAppear at \(String(format: "%.3f", now))")
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
                priestStore.priests = loadedPriests
                if mergedPrayers.count != prayersSnapshot.count {
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
