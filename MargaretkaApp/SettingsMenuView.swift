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
    @Binding var showEditor: Bool
    @Binding var showOsoby: Bool
    @Binding var showCzymJest: Bool
    @Binding var showJakSie: Bool
    @AppStorage("prayerSwipeMode") private var prayerSwipeModeRaw: String = PrayerSwipeMode.both.rawValue
    @AppStorage("prayerCompactView") private var prayerCompactView: Bool = false
    
    var body: some View {
        VStack
        {
            List {
                Section("Przesuwanie modlitw") {
                    Picker("Tryb", selection: $prayerSwipeModeRaw) {
                        ForEach(PrayerSwipeMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("W górę działa jak TikTok, w prawo jak Stories, a oba łączy oba gesty.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Widok") {
                    Toggle("Compact view", isOn: $prayerCompactView)

                    Text("Zmniejsza elementy listy modlitw i pokazuje 4 razy więcej na jednym rzędzie.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                NavigationLink("Modlitwy (pojedyncze)", destination: PrayerListSettingsView())

                NavigationLink(
                    destination: PriestListView(
                        store: priestStore,
                        availablePrayers: $availablePrayers,
                        showEditor: $showEditor,
                        category: .priest,
                        title: "Księża"
                    )
                ) {
                    Text("Księża")
                }
                
                NavigationLink(
                    destination: PriestListView(
                        store: priestStore,
                        availablePrayers: $availablePrayers,
                        showEditor: $showEditor,
                        category: .person,
                        title: "Osoby"
                    ),
                    isActive: $showOsoby
                ) {
                    Text("Osoby")
                }

                NavigationLink(
                    destination: PriestListView(
                        store: priestStore,
                        availablePrayers: $availablePrayers,
                        showEditor: $showEditor,
                        category: .prayer,
                        title: "Modlitwy złożone"
                    )
                ) {
                    Text("Modlitwy złożone")
                }
                
                NavigationLink(
                    destination: CzymJestMargaretkaView(),
                    isActive: $showCzymJest
                ) {
                    Text("Czym jest „Margaretka”?")
                }
                
                NavigationLink(
                    destination: JakSieModlicView(),
                    isActive: $showJakSie
                ) {
                    Text("Jak się modlić w Margaretce?")
                }
                NavigationLink("Statystyki", destination: StatsView())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Statystyki")
                    .accessibilityIdentifier("settings_stats_link")
            }
            .navigationTitle("Ustawienia")
            Text("© 2025\nDUSZEKJK Jacek Kałużny\nSoftware Development.\nAll rights reserved.")
                .multilineTextAlignment(.center)
            .padding(4)

        }
    }
}
