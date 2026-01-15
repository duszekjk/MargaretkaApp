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
        ensureDefaultPrayers()
    }

    private let key = "stored_prayers"

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Prayer].self, from: data) {
            self.prayers = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prayers) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func ensureDefaultPrayers() {
        let templateByName = Dictionary(uniqueKeysWithValues: prayersTemplate.values.map { ($0.name, $0) })
        var idMapping: [UUID: UUID] = [:]
        var updated: [Prayer] = []
        for prayer in prayers {
            if let template = templateByName[prayer.name] {
                if prayer.id != template.id {
                    idMapping[prayer.id] = template.id
                }
                updated.append(template)
            } else {
                updated.append(prayer)
            }
        }

        let existingNames = Set(updated.map { $0.name })
        for template in prayersTemplate.values where !existingNames.contains(template.name) {
            updated.append(template)
        }

        if updated != prayers {
            prayers = updated
            save()
        }

        if !idMapping.isEmpty {
            migrateAssignedPrayerIds(using: idMapping)
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

    private func migrateAssignedPrayerIds(using mapping: [UUID: UUID]) {
        let stored: [Priest] = LocalDatabase.shared.load(from: Priest.storageKey)
        var updatedPriests: [Priest] = []
        var changed = false

        for var priest in stored {
            let updatedGroups = priest.assignedPrayerGroups.map { updateGroup($0, mapping: mapping) }
            if updatedGroups != priest.assignedPrayerGroups {
                priest.assignedPrayerGroups = updatedGroups
                changed = true
            }
            updatedPriests.append(priest)
        }

        if changed {
            LocalDatabase.shared.save(updatedPriests, as: Priest.storageKey)
        }
    }

    private func updateGroup(_ group: AssignedPrayerGroup, mapping: [UUID: UUID]) -> AssignedPrayerGroup {
        let updatedItems: [AssignedPrayerItem] = group.items.map { item in
            switch item {
            case .prayer(let id):
                if let newId = mapping[id] {
                    return .prayer(newId)
                }
                return item
            case .subgroup:
                return item
            }
        }
        let updatedSubgroups = group.subgroups.map { updateGroup($0, mapping: mapping) }
        return AssignedPrayerGroup(id: group.id, items: updatedItems, repeatCount: group.repeatCount, subgroups: updatedSubgroups)
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
            priestStore.priests = Priest.loadWithTemplates()

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
