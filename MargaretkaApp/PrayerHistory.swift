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


    var body: some View {
        PrayerFlowView()
            .toolbar {
                NavigationLink(destination: SettingsMenuView(priestStore: priestStore, availablePrayers: $prayerStore.prayers)) {
                    Image(systemName: "gear")
                }
            }
            .onAppear()
        {
            var priestss = Priest.load()
            if(prayerStore.prayers.isEmpty)
            {
                prayerStore.prayers = Array(prayersTemplate.values)
                
                priestStore.priests = peopleTemplates
                for priest in priestStore.priests
                {
                    priest.save()
                }
            }
        }
    }
}
