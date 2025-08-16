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
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
                    .background(Color(.systemGroupedBackground))
                    .onAppear {
                        scheduleData.refresh()
                        
                    }
            }
        }
    }

}

