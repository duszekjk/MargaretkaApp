//
//  AppDelegate.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#else
import AppKit
#endif
import UserNotifications
import WebKit

#if os(iOS) || os(tvOS) || os(visionOS)
private typealias PlatformAppDelegate = UIApplicationDelegate
#else
private typealias PlatformAppDelegate = NSApplicationDelegate
#endif

final class AppDelegate: NSObject, PlatformAppDelegate, UNUserNotificationCenterDelegate {
#if os(iOS) || os(tvOS) || os(visionOS)
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
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.constrainMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.constrainMainWindow()
        }
    }
#endif

#if os(macOS)
    private func constrainMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.isVisible }),
              let screen = window.screen ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        let maximum = CGSize(
            width: max(640, visible.width - 80),
            height: max(480, visible.height - 80)
        )
        window.styleMask.insert(.resizable)
        window.contentMinSize = NSSize(width: 640, height: 480)
        window.contentMaxSize = maximum
        let current = window.contentView?.bounds.size ?? window.frame.size
        guard current.width > maximum.width || current.height > maximum.height else { return }

        window.setContentSize(CGSize(
            width: min(current.width, maximum.width),
            height: min(current.height, maximum.height)
        ))
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
#if os(iOS) || os(tvOS) || os(visionOS)
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
