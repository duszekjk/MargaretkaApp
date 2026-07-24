//
//  SettingsMenuView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import AppIntents
import Foundation
import SwiftUI
import _AppIntents_SwiftUI

struct SettingsMenuView: View {
    @ObservedObject var priestStore: PriestStore
    @Binding var availablePrayers: [Prayer]
    @Binding var showEditor: Bool
    @Binding var showOsoby: Bool
    @Binding var showCzymJest: Bool
    @Binding var showJakSie: Bool
    @AppStorage("prayerSwipeMode") private var prayerSwipeModeRaw: String = PrayerSwipeMode.both.rawValue
    @AppStorage("prayerCompactView") private var prayerCompactView: Bool = true

    private var savedTargets: [Priest] {
        priestStore.priests
    }

    private var exampleSiriCommands: [String] {
        let targetName = savedTargets.first?.name ?? "Anna"
        let secondTargetName = savedTargets.dropFirst().first?.name ?? "Father Piotr"
        return [
            "Hey Siri, start prayer for \(targetName) in Heptadaisy",
            "Hey Siri, log prayer for \(secondTargetName) in Heptadaisy",
            "Hey Siri, check prayer streak for \(targetName) in Heptadaisy",
            "Hey Siri, check average prayer duration for \(targetName) in Heptadaisy"
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

                Section {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Iskra — Siri, Skróty i NFC")
                                .font(.headline)

                            Text("Iskra to szybki sposób na uruchamianie modlitwy głosem albo jednym dotknięciem telefonu do znacznika NFC.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Jak to działa")
                                    .font(.subheadline.bold())
                                Text("1. Otwórz aplikację Skróty na iPhonie.")
                                Text("2. Dodaj skrót z akcją Heptadaisy i wybierz konkretną osobę albo modlitwę.")
                                Text("3. Powiedz Siri gotową angielską frazę albo uruchom skrót z automatyzacji NFC.")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                            SiriTipView(intent: StartPrayerIntent())
                                .siriTipViewStyle(.automatic)

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Przykładowe komendy")
                                    .font(.subheadline.bold())
                                ForEach(exampleSiriCommands, id: \.self) { command in
                                    Text("• \(command)")
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Text("Siri w tej aplikacji używa języka angielskiego, ponieważ Siri nie obsługuje języka polskiego. Wbudowane frazy zawierają nazwę Heptadaisy. Własnemu skrótowi możesz nadać krótszą nazwę.")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.footnote)

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("NFC — po co to?")
                                    .font(.subheadline.bold())
                                Text("Możesz przykleić znacznik NFC w miejscu modlitwy, przy różańcu, na biurku albo w samochodzie. W aplikacji Skróty utwórz automatyzację NFC, dodaj akcję Heptadaisy i wskaż w niej konkretną osobę albo modlitwę złożoną. Po dotknięciu iPhone'a tag uruchomi ten skrót.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("To dobre rozwiązanie, jeśli chcesz:\n• uruchamiać modlitwę jednym ruchem,\n• mieć jeden stały skrót przy konkretnym miejscu,\n• nie wpisywać nic ręcznie, gdy masz zajęte ręce.")
                                    .font(.footnote)
                            }

                            ShortcutsLink()
                                .shortcutsLinkStyle(.automatic)

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Skrót w skrócie")
                                    .font(.subheadline.bold())
                                Text("Siri → Heptadaisy → wybrana modlitwa")
                                    .font(.system(.body, design: .monospaced))
                                Text("NFC → automatyzacja Skrótów → Heptadaisy → wybrana modlitwa")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("Pomoc")
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
