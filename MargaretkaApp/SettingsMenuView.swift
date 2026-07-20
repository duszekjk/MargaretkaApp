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

    private var hasPriestAndPerson: Bool {
        let hasPriest = priestStore.priests.contains { $0.category == .priest }
        let hasPerson = priestStore.priests.contains { $0.category == .person }
        return hasPriest && hasPerson
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

                if hasPriestAndPerson {
                    Section {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Siri, Skróty i NFC")
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Siri uruchamia modlitwę głosem. NFC uruchamia ją po dotknięciu telefonu do taga przy stałym miejscu.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Divider()

                                VStack(alignment: .leading, spacing: 10) {
                                    Label {
                                        Text("Użyj Siri, gdy masz zajęte ręce lub chcesz start bez dotykania ekranu.")
                                            .fixedSize(horizontal: false, vertical: true)
                                    } icon: {
                                        Image(systemName: "mic.fill")
                                    }

                                    Label {
                                        Text("Użyj NFC, gdy chcesz jedno pewne uruchomienie w konkretnym miejscu.")
                                            .fixedSize(horizontal: false, vertical: true)
                                    } icon: {
                                        Image(systemName: "nfc")
                                    }
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Przykładowe komendy")
                                        .font(.subheadline.bold())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Start prayer for Różaniec")
                                        Text("• Log prayer for Koronka do Miłosierdzia Bożego")
                                        Text("• Check prayer streak for Modlitwa Apostolatu Margaretka")
                                        Text("• What is the average prayer duration for Modlitwa św. Jana Pawła II za kapłanów")
                                    }
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                                }

                                Text("Nazwa aplikacji jest dopasowywana automatycznie, więc w codziennym użyciu nie musisz jej powtarzać w każdej frazie.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Dlaczego NFC jest przydatne")
                                        .font(.subheadline.bold())

                                    Text("Sprawdza się przy różańcu, przy łóżku, przy biurku albo w samochodzie. Dotykasz taga i od razu startuje właściwy skrót.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("To wygodne, gdy:\n• chcesz oszczędzić czas,\n• nie chcesz mówić do telefonu,\n• masz zawsze to samo miejsce modlitwy.")
                                        .font(.footnote)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Flow")
                                        .font(.subheadline.bold())
                                    Text("Siri → skrót → modlitwa")
                                        .font(.system(.body, design: .monospaced))
                                    Text("NFC → tag → skrót → modlitwa")
                                        .font(.system(.body, design: .monospaced))
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Pomoc")
                    }
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
