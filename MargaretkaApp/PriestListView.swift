//
//  PriestListView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//
import SwiftUI

struct PriestListView: View {
    @ObservedObject var store: PriestStore
    @Binding var availablePrayers: [Prayer]
    @Binding var showEditor: Bool
    @State var selectedPriest: Priest?
    let category: PrayerTargetCategory
    let title: String
    var body: some View {

        ScheduleList<Priest>(
            title: title,
            saveKey: "priest_sch",
            forceFrequency: .weekly,
            forever: true,
            itemSummary: { $0.displayName },
            formBuilder: { existing in
                if let existing {
                    return existing
                }
                return Priest(
                    id: UUID(),
                    firstName: "",
                    lastName: "",
                    title: "",
                    category: category,
                    assignedPrayerGroups: [],
                    schedule: SchedulePlan(),
                    lastModified: Date(),
                    notificationTitle: "Time to pray",
                    notificationMessage: ""
                )
            },
            formFields: { nowPriest in
                return AnyView(
                    VStack() {
                        PriestEditorView(store: store, priest: nowPriest, availablePrayers: $availablePrayers)
                    }
                )
            },
            onAdd: { newPriest in
                newPriest.save()
                store.addOrUpdate(newPriest)
            },
            filter: { $0.category == category },
            showingForm: $showEditor
        )


    }
}
