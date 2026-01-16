//
//  MargaretkaAppApp.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI
import AudioToolbox

@main
struct MargaretkaAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
    @StateObject var scheduleData = ScheduleData<Priest>(saveKey: "priest_sch")
    @State private var didScheduleNotificationRefresh = false
    @State private var showUiTestGate = ProcessInfo.processInfo.arguments.contains("--ui-tests")

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
                    .background(Color(.systemGroupedBackground))
                    .onAppear {
                        scheduleNotificationRefresh()
                    }
            }
            .overlay {
                if showUiTestGate {
                    UiTestGateView(isPresented: $showUiTestGate)
                }
            }
        }
    }

    private func scheduleNotificationRefresh() {
        guard !didScheduleNotificationRefresh else { return }
        didScheduleNotificationRefresh = true

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5.0) {
            scheduleData.rescheduleAll()
        }
    }
}


struct UiTestGateView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Testy UI uruchomione")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Odblokuj telefon i dotknij Kontynuuj, aby rozpoczac.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))

                Button("Kontynuuj") {
                    isPresented = false
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.white.opacity(0.9))
                )
                .foregroundStyle(.black)
                .accessibilityIdentifier("ui_test_continue")
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.7))
            )
            .padding(32)
        }
        .accessibilityIdentifier("ui_test_gate")
        .onAppear {
            AudioServicesPlaySystemSound(1057)
        }
    }
}
