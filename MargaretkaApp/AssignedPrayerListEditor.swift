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
//        List {
        ScrollView
        {
            ForEach($groups) { $group in
                GroupEditorView(group: $group, availablePrayers: $availablePrayers)
            }
            
            Button {
                groups.append(AssignedPrayerGroup())
            } label: {
                Label("Dodaj nową grupę", systemImage: "plus")
            }
        }
//        }
    }
}

struct GroupEditorView: View {
    @Binding var group: AssignedPrayerGroup
    @Binding var availablePrayers: [Prayer]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Powtórz \(group.repeatCount)x")
                Stepper("", value: $group.repeatCount, in: 1...99)
            }

            ForEach(group.items, id: \.id) { item in
                switch item {
                case .prayer(let prayerId):
                    if let prayer = availablePrayers.first(where: { $0.id == prayerId }) {
                        HStack {
                            Label(prayer.name, systemImage: prayer.symbol)
                            Spacer()
                            Button(role: .destructive) {
                                if let index = group.items.firstIndex(of: item) {
                                    group.items.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                        }
                    } else {
                        Text("Nieznana modlitwa")
                    }

                case .subgroup(let subgroupIndex):
                    if subgroupIndex < group.subgroups.count {
                        GroupEditorView(group: $group.subgroups[subgroupIndex], availablePrayers: $availablePrayers)
                            .padding(.leading)
                    } else {
                        Text("Nieznana podgrupa")
                    }
                }
            }

            Menu {
                ForEach(availablePrayers) { prayer in
                    Button {
                        group.items.append(.prayer(prayer.id))
                    } label: {
                        Label(prayer.name, systemImage: prayer.symbol)
                    }
                }
            } label: {
                Label("Dodaj modlitwę", systemImage: "plus")
            }

            Button {
                let newIndex = group.subgroups.count
                group.subgroups.append(AssignedPrayerGroup())
                group.items.append(.subgroup(newIndex))
            } label: {
                Label("Dodaj nową podgrupę", systemImage: "plus")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
