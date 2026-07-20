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
    @AppStorage("prayerCompactView") private var prayerCompactView: Bool = true
    
    var body: some View {
        VStack
        {
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

            }
            .navigationTitle("Ustawienia")
            Text("© 2025\nDUSZEKJK Jacek Kałużny\nSoftware Development.\nAll rights reserved.")
                .multilineTextAlignment(.center)
            .padding(4)

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
                        Text("2. Dodaj skrót z akcji Margaretki.")
                        Text("3. Powiedz Siri gotową frazę albo uruchom skrót z NFC.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Przykładowe komendy")
                            .font(.subheadline.bold())

                        HStack(alignment: .top, spacing: 12) {
                            Text("•")
                            Text("Start prayer for Anna in Margaretka")
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Text("•")
                            Text("Log prayer for Father Piotr in Margaretka")
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Text("•")
                            Text("Check prayer streak for Maria in Margaretka")
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Text("•")
                            Text("What is the average prayer duration for Jan in Margaretka")
                        }
                    }
                    .font(.footnote)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("NFC — po co to?")
                            .font(.subheadline.bold())

                        Text("Możesz przykleić znacznik NFC w miejscu modlitwy, przy różańcu, na biurku albo w samochodzie. Po dotknięciu iPhone'a tag uruchomi wybrany skrót, więc nie musisz szukać aplikacji ani mówić do Siri.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("To dobre rozwiązanie, jeśli chcesz:\n• uruchamiać modlitwę jednym ruchem,\n• mieć jeden stały skrót przy konkretnym miejscu,\n• nie wpisywać nic ręcznie, gdy masz zajęte ręce.")
                            .font(.footnote)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Skrót w skrócie")
                            .font(.subheadline.bold())
                        Text("Siri → skrót → modlitwa")
                            .font(.system(.body, design: .monospaced))
                        Text("NFC → dotknięcie taga → skrót → modlitwa")
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.vertical, 6)
            } label: {
                Text("Pomoc")
            }

        }
    }
}
