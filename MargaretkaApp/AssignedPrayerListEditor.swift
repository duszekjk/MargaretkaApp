//
//  AssignedPrayerListEditor.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI
struct AssignedPrayerListEditor: View {
    @Binding var groups: [AssignedPrayerGroup]
    @Binding var availablePrayers: [Prayer]

    var body: some View {
        List {
            ForEach($groups) { $group in
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Powtórz \(group.repeatCount)x")
                            Stepper("", value: $group.repeatCount, in: 1...99)
                        }
                        ForEach(group.prayerIds.indices, id: \.self) { i in
                            HStack {
                                let prayerId = group.prayerIds[i]
                                if let prayer = availablePrayers.first(where: { $0.id == prayerId }) {
                                    Label(prayer.name, systemImage: prayer.symbol)
                                } else {
                                    Text("Nieznana modlitwa")
                                }
                                Spacer()
                                Button(action: {
                                    group.prayerIds.remove(at: i)
                                }) {
                                    Image(systemName: "minus.circle")
                                }
                            }
                            .frame(height:40.0)
                        }
                        Menu {
                            ForEach(availablePrayers) { prayer in
                                Button(action: {
                                    group.prayerIds.append(prayer.id)
                                }) {
                                    Label(prayer.name, systemImage: prayer.symbol)
                                }
                            }
                        } label: {
                            Label("Dodaj modlitwę", systemImage: "plus")
                                .frame(height:40.0)
                        }
                    }
                } header: {
                    Text("Grupa")
                }
            }
            .onDelete { indexSet in
                groups.remove(atOffsets: indexSet)
            }

            Button {
                groups.append(AssignedPrayerGroup(prayerIds: [], repeatCount: 1))
            } label: {
                Label("Dodaj nową grupę", systemImage: "plus")
            }
            
        }
        .navigationTitle("Modlitwy księdza")
    }
}
