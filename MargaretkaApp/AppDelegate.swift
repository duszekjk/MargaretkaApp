//
//  AppDelegate.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

import UIKit
import UserNotifications
import WebKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        migrateLegacyPreferenceTemporaryFiles()
        cleanLegacyWebCachesIfNeeded()
        return true
    }

    private func migrateLegacyPreferenceTemporaryFiles() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return
        }

        let preferences = library.appendingPathComponent("Preferences", isDirectory: true)
        let temporaryPrefix = bundleIdentifier + ".plist."
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: preferences,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for file in files where file.lastPathComponent.hasPrefix(temporaryPrefix) {
            guard let snapshot = NSDictionary(contentsOf: file) as? [String: Any] else { continue }
            restorePrayerDataIfNeeded(from: snapshot)
            restorePriestDataIfNeeded(from: snapshot)
            restorePrayerSessionDataIfNeeded(from: snapshot)
        }
    }

    private func restorePrayerDataIfNeeded(from snapshot: [String: Any]) {
        guard let legacyData = snapshot["stored_prayers"] as? Data else { return }
        let current: [Prayer] = LocalDatabase.shared.load(from: "stored_prayers")
        guard current.isEmpty else { return }

        let candidateData = (try? LocalDatabase.unpackedPayload(from: legacyData)) ?? legacyData
        guard let decoded = try? JSONDecoder().decode([Prayer].self, from: candidateData), !decoded.isEmpty else { return }
        LocalDatabase.shared.save(decoded, as: "stored_prayers")
    }

    private func restorePriestDataIfNeeded(from snapshot: [String: Any]) {
        guard let legacyData = snapshot["stored_priests"] as? Data else { return }
        let current: [Priest] = LocalDatabase.shared.load(from: Priest.storageKey)
        guard current.isEmpty else { return }

        let candidateData = (try? LocalDatabase.unpackedPayload(from: legacyData)) ?? legacyData
        guard let decoded = try? JSONDecoder().decode([Priest].self, from: candidateData), !decoded.isEmpty else { return }
        LocalDatabase.shared.save(decoded, as: Priest.storageKey)
    }

    private func restorePrayerSessionDataIfNeeded(from snapshot: [String: Any]) {
        guard let legacyData = snapshot[PrayerSessionStore.saveKey] as? Data else { return }
        let current: [PrayerSession] = LocalDatabase.shared.load(from: PrayerSessionStore.saveKey)
        guard current.isEmpty else { return }

        let candidateData = (try? LocalDatabase.unpackedPayload(from: legacyData)) ?? legacyData
        guard let decoded = try? JSONDecoder().decode([PrayerSession].self, from: candidateData), !decoded.isEmpty else { return }
        LocalDatabase.shared.save(decoded, as: PrayerSessionStore.saveKey)
    }

    private func cleanLegacyWebCachesIfNeeded() {
        let cleanupKey = "legacy_web_cache_cleanup_v1"
        guard !UserDefaults.standard.bool(forKey: cleanupKey) else { return }

        URLCache.shared.removeAllCachedResponses()
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {
            UserDefaults.standard.set(true, forKey: cleanupKey)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let itemId = userInfo["itemId"] as? String
        let eventTime = userInfo["eventTime"] as? Double

        switch response.actionIdentifier {
        case notificationActionRestart, UNNotificationDefaultActionIdentifier:
            Task { @MainActor in
                PrayerNotificationRouter.shared.requestPrayer(itemId: itemId)
            }
        case notificationActionMarkDone:
            NotificationCenter.default.post(
                name: .prayerMarkDoneRequested,
                object: (itemId, eventTime)
            )
        default:
            break
        }

        completionHandler()
    }
}
