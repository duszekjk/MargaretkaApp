//
//  SettingsMenuView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI

struct SettingsMenuView: View {
    @ObservedObject var priestStore: PriestStore
    @Binding var availablePrayers: [Prayer]
    
    var body: some View {
        List {
            NavigationLink("Modlitwy", destination: PrayerListSettingsView())
            NavigationLink("Osoby", destination: PriestListView(store: priestStore, availablePrayers: $availablePrayers))
//            NavigationLink("Statystyki", destination: StatsView())
            Spacer()
            Text("DUSZEKJK Jacek Kałużny Software Development")
        }
        .navigationTitle("Ustawienia")
    }
}
