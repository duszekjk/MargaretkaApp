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
    var requestedAddCategory: Binding<PrayerTargetCategory?>? = nil
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
                    notificationTitle: category.notificationTitle(for: ""),
                    notificationMessage: category.notificationMessage(for: "")
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
            filter: { target in
                target.category == category && target.isNotificationScheduleRepresentative
            },
            showingForm: $showEditor
        )
        .onAppear {
            guard requestedAddCategory?.wrappedValue == category else { return }
            requestedAddCategory?.wrappedValue = nil
            DispatchQueue.main.async { showEditor = true }
        }


    }
}
