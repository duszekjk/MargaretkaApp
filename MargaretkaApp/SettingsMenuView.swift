//
//  SettingsMenuView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import AppIntents
import Foundation
import SwiftUI

struct SettingsMenuView: View {
    @ObservedObject var priestStore: PriestStore
    @Binding var availablePrayers: [Prayer]
    @Binding var showEditor: Bool
    @Binding var showOsoby: Bool
    @Binding var showCzymJest: Bool
    @Binding var showJakSie: Bool
    @AppStorage("prayerSwipeMode") private var prayerSwipeModeRaw: String = PrayerSwipeMode.both.rawValue
    @AppStorage("prayerCompactView") private var prayerCompactView: Bool = true

    private var exampleSiriCommands: [String] {
        return [
            "Hey Siri, start prayer in Heptadaisy",
            "Hey Siri, log prayer in Heptadaisy",
            "Hey Siri, check prayer streak in Heptadaisy",
            "Hey Siri, check average prayer duration in Heptadaisy"
        ]
    }
    
    var body: some View {
        List {
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

                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label("Synchronizuj", systemImage: "arrow.triangle.2.circlepath.icloud")
                }

                NavigationLink(
                    destination: DataTransferView(targetStore: priestStore)
                ) {
                    Label("Import i eksport", systemImage: "arrow.up.arrow.down.circle")
                }
                
                    Section("Przesuwanie modlitw") {
                        Picker("Tryb", selection: $prayerSwipeModeRaw) {
                            ForEach(PrayerSwipeMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("W górę działa jak TikTok, w prawo jak Instagram Stories, a oba pozwala na oba gesty.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Widok") {
                        Toggle("Compact view", isOn: $prayerCompactView)

                        Text("Zmniejsza elementy listy modlitw")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                Section("Siri and Shortcuts") {
                    SiriTipView(intent: StartPrayerIntent())
                        .siriTipViewStyle(.automatic)

                    ForEach(exampleSiriCommands, id: \.self) { command in
                        Text(command)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Siri uses English for these commands. Built-in phrases include the app name. For an NFC tag, open Shortcuts, create an NFC automation, and run one of these actions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ShortcutsLink()
                        .shortcutsLinkStyle(.automatic)
                }

                Section {
                    Text("© 2025\nDUSZEKJK Jacek Kałużny\nSoftware Development.\nAll rights reserved.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
        }
        .navigationTitle("Ustawienia")
    }
}
