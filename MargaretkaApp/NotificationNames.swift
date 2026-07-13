//
//  NotificationNames.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

import Foundation
internal import Combine

struct PrayerNotificationRoute: Equatable, Identifiable {
    let id = UUID()
    let itemId: UUID
}

@MainActor
final class PrayerNotificationRouter: ObservableObject {
    static let shared = PrayerNotificationRouter()

    @Published private(set) var pendingRoute: PrayerNotificationRoute?

    func requestPrayer(itemId: String?) {
        guard let itemId, let uuid = UUID(uuidString: itemId) else { return }
        pendingRoute = PrayerNotificationRoute(itemId: uuid)
    }

    func consume(_ route: PrayerNotificationRoute) {
        guard pendingRoute?.id == route.id else { return }
        pendingRoute = nil
    }
}

extension Notification.Name {
    static let prayerRestartRequested = Notification.Name("prayerRestartRequested")
    static let prayerMarkDoneRequested = Notification.Name("prayerMarkDoneRequested")
}
