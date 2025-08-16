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
    @State private var showEditor = false
    @State private var selectedPriest: Priest?

    var body: some View {

        ScheduleList<Priest>(title: "Priests", saveKey: "priest_sch", forceFrequency: .weekly, forever: true, itemSummary: {
                return "\($0.title) \($0.firstName) \($0.lastName)"
                
            }, formBuilder: {existing in
                if(existing != nil)
                {
                    return existing!
                }
                return Priest(id: UUID(), firstName: "", lastName: "", title: "", assignedPrayerGroups: [], schedule: SchedulePlan(), lastModified: Date(), notificationTitle: "Time to pray", notificationMessage: "")
            }, formFields:
            { nowPriest in
                return AnyView(
                    VStack()
                    {
                        PriestEditorView(store: store, priest:nowPriest, availablePrayers: $availablePrayers)
                    }
                )
                
            }, onAdd:
            { newPriest in
                    newPriest.save()
                    store.addOrUpdate(newPriest)
            }, showingForm: $showEditor
            )


























    }
}
