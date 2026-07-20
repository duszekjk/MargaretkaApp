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
                                        Text("• Siri, rozpocznij modlitwę za wybranego kapłana")
                                        Text("• Siri, zapisz modlitwę dla wybranej osoby")
                                        Text("• Siri, sprawdź serię modlitwy dla Różańca")
                                        Text("• Siri, jaki jest średni czas modlitwy dla Koronki do Miłosierdzia Bożego")
                                    }
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                                }

                                Text("Te zdania możesz powiedzieć prawie tak samo. Nie musisz umieć dobrze angielskiego — wystarczy powtórzyć je po swojemu, a Siri i tak spróbuje zrozumieć, o co chodzi.")
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
