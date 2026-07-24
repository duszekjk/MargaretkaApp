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

    nonisolated private static let defaultStore = UserDefaults(suiteName: "group.com.duszekjk.MargaretkaApp") ?? .standard
    nonisolated private static let pendingItemIDKey = "pending_prayer_route_item_id"

    private let store: UserDefaults
    @Published private(set) var pendingRoute: PrayerNotificationRoute?

    init(store: UserDefaults = PrayerNotificationRouter.defaultStore) {
        self.store = store
        if let itemID = store.string(forKey: Self.pendingItemIDKey),
           let uuid = UUID(uuidString: itemID) {
            pendingRoute = PrayerNotificationRoute(itemId: uuid)
        }
    }

    func requestPrayer(itemId: String?) {
        guard let itemId, let uuid = UUID(uuidString: itemId) else { return }
        store.set(uuid.uuidString, forKey: Self.pendingItemIDKey)
        pendingRoute = PrayerNotificationRoute(itemId: uuid)
    }

    func consume(_ route: PrayerNotificationRoute) {
        guard pendingRoute?.id == route.id else { return }
        store.removeObject(forKey: Self.pendingItemIDKey)
        pendingRoute = nil
    }
}

extension Notification.Name {
    static let prayerRestartRequested = Notification.Name("prayerRestartRequested")
    static let prayerMarkDoneRequested = Notification.Name("prayerMarkDoneRequested")
    static let localDataChanged = Notification.Name("localDataChanged")
}

struct LocalDataChange {
    let filename: String
    let changedIDs: Set<String>
    let deletedIDs: Set<String>
}
