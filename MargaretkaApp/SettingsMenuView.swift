//
//  SettingsMenuView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

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

    private var hasPriestAndPerson: Bool {
        let hasPriest = priestStore.priests.contains { $0.category == .priest }
        let hasPerson = priestStore.priests.contains { $0.category == .person }
        return hasPriest && hasPerson
    }

    private var examplePriestName: String {
        priestStore.priests.first(where: { $0.category == .priest })?.displayName ?? "wybrany kapłan"
    }

    private var examplePersonName: String {
        priestStore.priests.first(where: { $0.category == .person })?.displayName ?? "wybrana osoba"
    }

    private var exampleComplexPrayerNames: [String] {
        let names = priestStore.priests
            .filter { $0.category == .prayer }
            .map(\.displayName)
            .filter { !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty }
        return names.isEmpty ? ["Różaniec", "Koronka do Miłosierdzia Bożego"] : names
    }

    private var exampleSiriCommands: [String] {
        let prayers = exampleComplexPrayerNames
        let firstPrayer = prayers.first ?? "Różaniec"
        let secondPrayer = prayers.dropFirst().first ?? firstPrayer
        return [
            "• Siri, start prayer for \(examplePriestName) in Heptadaisy",
            "• Siri, start prayer for \(examplePersonName) in Heptadaisy",
            "• Siri, check prayer streak for \(firstPrayer) in Heptadaisy",
            "• Siri, check average prayer duration for \(secondPrayer) in Heptadaisy"
        ]
    }
    
    var body: some View {
        List {
                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label("Synchronizuj", systemImage: "arrow.triangle.2.circlepath.icloud")
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

                if hasPriestAndPerson {
                    Section {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Siri, Skróty i NFC")
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Jeśli chcesz, możesz uruchamiać modlitwę głosem albo przez dotknięcie telefonu do taga NFC. Nie musisz znać technicznych ustawień — wystarczy gotowe zdanie albo zwykłe dotknięcie telefonu.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Divider()

                                VStack(alignment: .leading, spacing: 10) {
                                    Label {
                                        Text("Powiedz do Siri gotowe zdanie, gdy chcesz zacząć bez klikania.")
                                            .fixedSize(horizontal: false, vertical: true)
                                    } icon: {
                                        Image(systemName: "mic.fill")
                                    }

                                    Label {
                                        Text("Przyklej tag NFC do zdjęcia osoby albo do kartki z imieniem i dotknij go telefonem.")
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
                                        ForEach(exampleSiriCommands, id: \.self) { command in
                                            Text(command)
                                        }
                                    }
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                                }

                                Text("To są gotowe zdania. Siri podstawia nazwę kapłana, osoby albo modlitwy, które masz zapisane.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Dlaczego NFC jest przydatne")
                                        .font(.subheadline.bold())

                                    Text("Najlepiej działa przy ikonie, obrazie, zdjęciu osoby albo przy kartce z imieniem. Dotykasz taga i od razu startuje właściwa modlitwa dla tej osoby.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("To wygodne, gdy:\n• chcesz uruchomić modlitwę przy konkretnej osobie,\n• chcesz mieć jedną prostą czynność zamiast szukania w telefonie,\n• modlisz się zawsze w tym samym miejscu.")
                                        .font(.footnote)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
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
