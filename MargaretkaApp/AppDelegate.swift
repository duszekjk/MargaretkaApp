//
//  AppDelegate.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UserNotifications
import WebKit

#if canImport(UIKit)
private typealias PlatformAppDelegate = UIApplicationDelegate
#else
private typealias PlatformAppDelegate = NSApplicationDelegate
#endif

final class AppDelegate: NSObject, PlatformAppDelegate, UNUserNotificationCenterDelegate {
#if canImport(UIKit)
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        cleanStalePreferenceTemporaryFiles()
        cleanLegacyWebCachesIfNeeded()
        return true
    }
#else
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        cleanStalePreferenceTemporaryFiles()
        cleanLegacyWebCachesIfNeeded()
    }
#endif

    private func cleanStalePreferenceTemporaryFiles() {
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

        let staleBefore = Date().addingTimeInterval(-24 * 60 * 60)
        for file in files where file.lastPathComponent.hasPrefix(temporaryPrefix) {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified < staleBefore else { continue }
            try? FileManager.default.removeItem(at: file)
        }
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
#if canImport(UIKit)
        completionHandler([.banner, .sound, .badge, .list])
#else
        completionHandler([.alert, .sound, .badge])
#endif
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
