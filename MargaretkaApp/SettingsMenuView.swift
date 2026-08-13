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
    @Binding var menuTargetCategory: PrayerTargetCategory?
    @AppStorage("prayerSwipeMode") private var prayerSwipeModeRaw: String = PrayerSwipeMode.both.rawValue
    @AppStorage("prayerCompactView") private var prayerCompactView: Bool = true

    private var savedTargets: [Priest] {
        priestStore.priests
    }

    private var exampleSiriCommands: [String] {
        let targetName = savedTargets.first?.displayName ?? "Anna"
        let secondTargetName = savedTargets.dropFirst().first?.displayName ?? "Father Piotr"
        return [
            "Hey Siri, start prayer for \(targetName) in Heptadaisy",
            "Hey Siri, log prayer for \(secondTargetName) in Heptadaisy",
            "Hey Siri, check prayer streak for \(targetName) in Heptadaisy",
            "Hey Siri, check average prayer duration for \(targetName) in Heptadaisy"
        ]
    }
    
    var body: some View {
        List {
                NavigationLink("Modlitwy (pojedyncze)", destination: PrayerListSettingsView(priestStore: priestStore))

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
                
                NavigationLink {
                    peopleList
                } label: {
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
                
                NavigationLink {
                    CzymJestMargaretkaView()
                } label: {
                    Text("Czym jest „Margaretka”?")
                }
                
                NavigationLink {
                    JakSieModlicView()
                } label: {
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

                NavigationLink {
                    OfflineBreviaryManagerView()
                } label: {
                    Label("Brewiarz offline", systemImage: "book.closed")
                }

                NavigationLink {
                    StorageSettingsView(priestStore: priestStore)
                } label: {
                    Label("Pamięć", systemImage: "internaldrive")
                }

                NavigationLink {
                    PrayerAutoAdvanceSettingsView()
                } label: {
                    Label("Automatyczne przełączanie", systemImage: "waveform.and.mic")
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
                            Text("Siri, Skróty i NFC")
                                .font(.headline)

                            Text("To szybki sposób na uruchamianie modlitwy głosem albo jednym dotknięciem telefonu do znacznika NFC.")
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

#if !os(macOS)
                            SiriTipView(intent: StartPrayerIntent())
                                .siriTipViewStyle(.automatic)
#endif

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
                            }

#if !os(macOS)
                            ShortcutsLink()
                                .shortcutsLinkStyle(.automatic)
#endif

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
        .navigationDestination(isPresented: $showOsoby) {
            peopleList
        }
        .navigationDestination(isPresented: $showCzymJest) {
            CzymJestMargaretkaView()
        }
        .navigationDestination(isPresented: $showJakSie) {
            JakSieModlicView()
        }
        .navigationDestination(isPresented: Binding(
            get: { menuTargetCategory != nil },
            set: { if !$0 { menuTargetCategory = nil } }
        )) {
            if let category = menuTargetCategory {
                PriestListView(
                    store: priestStore,
                    availablePrayers: $availablePrayers,
                    showEditor: $showEditor,
                    category: category,
                    title: category.displayName,
                    requestedAddCategory: $menuTargetCategory
                )
            }
        }
    }

    private var peopleList: some View {
        PriestListView(
            store: priestStore,
            availablePrayers: $availablePrayers,
            showEditor: $showEditor,
            category: .person,
            title: "Osoby"
        )
    }
}
