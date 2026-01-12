//
//  MargaretkaAppApp.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI

@main
struct MargaretkaAppApp: App {
    @StateObject var scheduleData = ScheduleData<Priest>(saveKey: "priest_sch")
    @State private var didScheduleNotificationRefresh = false
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
                    .background(Color(.systemGroupedBackground))
                    .onAppear {
                        scheduleNotificationRefresh()
                    }
            }
        }
    }

    private func scheduleNotificationRefresh() {
        guard !didScheduleNotificationRefresh else { return }
        didScheduleNotificationRefresh = true

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5.0) {
            scheduleData.refresh()
        }
    }
}
