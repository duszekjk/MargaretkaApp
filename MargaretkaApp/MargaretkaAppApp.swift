//
//  MargaretkaAppApp.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import AppIntents
import SwiftUI
import AudioToolbox
#if os(macOS)
import AppKit
#endif

@main
struct MargaretkaAppApp: App {
#if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
#else
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
#endif
    @StateObject var scheduleData = ScheduleData<Priest>(saveKey: "priest_sch")
    @StateObject var prayerStore = PrayerStore()
    @StateObject var priestStore = PriestStore()
    @StateObject var offlineBreviaryStore = OfflineBreviaryStore()
    @StateObject var syncService = SyncService.shared
    @State private var didScheduleNotificationRefresh = false
    @State private var showUiTestGate = ProcessInfo.processInfo.arguments.contains("--ui-tests")
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MargaretkaAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
#if os(macOS)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .background(AppDelegate.MacWindowConfigurator())
#else
                    .background(Color(.systemGroupedBackground))
#endif
                    .onAppear {
                        scheduleNotificationRefresh()
                        syncService.configureStores(
                            prayerStore: prayerStore,
                            targetStore: priestStore,
                            offlineStore: offlineBreviaryStore
                        )
#if os(macOS)
                        (NSApp.delegate as? AppDelegate)?.configureMargaretkaMenu()
#endif
                    }
            }
            .environmentObject(scheduleData)
            .environmentObject(prayerStore)
            .environmentObject(priestStore)
            .environmentObject(offlineBreviaryStore)
            .environmentObject(syncService)
            .overlay {
                if showUiTestGate {
                    UiTestGateView(isPresented: $showUiTestGate)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    offlineBreviaryStore.removeExpired()
                }
            }
        }
#if os(macOS)
        .defaultSize(width: 1100, height: 800)
        .windowResizability(.automatic)
#endif
    }

    private func scheduleNotificationRefresh() {
        guard !didScheduleNotificationRefresh else { return }
        didScheduleNotificationRefresh = true

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5.0) {
            print("📅 ScheduleData notification refresh dispatched")
            scheduleData.rescheduleAll()
        }
    }
}

extension Notification.Name {
    static let margaretkaNewPerson = Notification.Name("margaretka.newPerson")
    static let margaretkaSettings = Notification.Name("margaretka.settings")
    static let margaretkaAbout = Notification.Name("margaretka.about")
    static let margaretkaHowTo = Notification.Name("margaretka.howTo")
    static let margaretkaSync = Notification.Name("margaretka.sync")
    static let margaretkaSyncSettings = Notification.Name("margaretka.syncSettings")
    static let margaretkaPrayerList = Notification.Name("margaretka.prayerList")
    static let margaretkaToggleCompact = Notification.Name("margaretka.toggleCompact")
    static let margaretkaSelectTarget = Notification.Name("margaretka.selectTarget")
    static let margaretkaMenuNeedsRefresh = Notification.Name("margaretka.menuNeedsRefresh")
    static let margaretkaImport = Notification.Name("margaretka.import")
    static let margaretkaStatistics = Notification.Name("margaretka.statistics")
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
