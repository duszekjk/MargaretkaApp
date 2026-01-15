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
        didSet { save() }
    }

    init() {
        load()
    }

    private let key = "stored_prayers"

    private func load() {
        var loaded: [Prayer] = []
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Prayer].self, from: data) {
            loaded = decoded
        }
        self.prayers = mergeDefaultPrayers(into: loaded)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prayers) {
            UserDefaults.standard.set(data, forKey: key)
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
    @StateObject var prayerStore = PrayerStore()
    
    
    @State var showSettings: Bool = false
    @State var showEditor: Bool = false
    @State var showOsoby: Bool = false
    @State var showCzymJest: Bool = false
    @State var showJakSie: Bool = false

    private func templateKey(for priest: Priest) -> String {
        "\(priest.category.rawValue)|\(priest.title)|\(priest.firstName)|\(priest.lastName)"
    }

    var body: some View {
        PrayerFlowView(showSettings: $showSettings, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie)
            .toolbar {
                NavigationLink(destination: SettingsMenuView(priestStore: priestStore, availablePrayers: $prayerStore.prayers, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie),
                               isActive: $showSettings) {
                    Image(systemName: "gear")
                }
            }
            .onAppear()
        {
            var storedPriests = Priest.load()
            var storedPriestKeys = Set(storedPriests.map { templateKey(for: $0) })
            for template in peopleTemplates {
                let key = templateKey(for: template)
                if !storedPriestKeys.contains(key) {
                    storedPriests.append(template)
                    storedPriestKeys.insert(key)
                    template.save()
                }
            }
            priestStore.priests = storedPriests

            let templatePrayers = Array(prayersTemplate.values)
            let existingPrayerNames = Set(prayerStore.prayers.map { $0.name })
            var mergedPrayers = prayerStore.prayers
            for template in templatePrayers where !existingPrayerNames.contains(template.name) {
                mergedPrayers.append(template)
            }
            if mergedPrayers.count != prayerStore.prayers.count {
                prayerStore.prayers = mergedPrayers
            }
        }
    }
}
