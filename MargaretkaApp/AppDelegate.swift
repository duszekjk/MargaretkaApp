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
import SwiftUI
import UserNotifications
import WebKit

#if os(iOS) || os(tvOS) || os(visionOS)
private typealias PlatformAppDelegate = UIApplicationDelegate
#else
private typealias PlatformAppDelegate = NSApplicationDelegate
#endif

#if os(macOS)
private final class MacMenuTarget: NSObject {
    @objc func newPerson() { NotificationCenter.default.post(name: .margaretkaNewPerson, object: nil) }
    @objc func settings() { NotificationCenter.default.post(name: .margaretkaSettings, object: nil) }
    @objc func about() { NotificationCenter.default.post(name: .margaretkaAbout, object: nil) }
}
#endif

final class AppDelegate: NSObject, PlatformAppDelegate, UNUserNotificationCenterDelegate {
#if os(macOS)
    private let menuTarget = MacMenuTarget()
#endif
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
        configureMargaretkaMenu()
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
    private func configureMargaretkaMenu() {
        let menu = NSMenu()
        let file = NSMenu(title: "Plik")
        file.addItem(withTitle: "Dodaj osobę do modlitwy", action: #selector(MacMenuTarget.newPerson), keyEquivalent: "n").target = menuTarget
        file.addItem(.separator())
        file.addItem(withTitle: "Zakończ Margaretkę", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp

        let view = NSMenu(title: "Widok")
        view.addItem(withTitle: "Pełny ekran", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f").target = nil

        let help = NSMenu(title: "Pomoc")
        help.addItem(withTitle: "O aplikacji Margaretka", action: #selector(MacMenuTarget.about), keyEquivalent: "").target = menuTarget

        let customMenus: [(String, NSMenu)] = [
            ("Plik", file),
            ("Księża", NSMenu(title: "Księża")),
            ("Osoby", NSMenu(title: "Osoby")),
            ("Modlitwy", NSMenu(title: "Modlitwy")),
            ("Widok", view),
            ("Pomoc", help)
        ]
        customMenus[1].1.addItem(withTitle: "Dodaj księdza", action: #selector(MacMenuTarget.newPerson), keyEquivalent: "").target = menuTarget
        customMenus[2].1.addItem(withTitle: "Dodaj osobę", action: #selector(MacMenuTarget.newPerson), keyEquivalent: "").target = menuTarget
        customMenus[3].1.addItem(withTitle: "Rozpocznij modlitwę", action: #selector(MacMenuTarget.settings), keyEquivalent: "").target = menuTarget
        for (title, submenu) in customMenus {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            menu.addItem(item)
        }
        let settings = NSMenuItem(title: "Ustawienia Margaretki", action: #selector(MacMenuTarget.settings), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = [.command]
        settings.target = menuTarget
        view.addItem(settings)
        NSApp.mainMenu = menu
    }

    struct MacWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
            DispatchQueue.main.async { self.updateNSView(nsView, context: context) }
            return
        }
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let minimum = NSSize(width: 320, height: 256)
        let maximum = NSSize(
            width: max(minimum.width, visible.width - 40),
            height: max(minimum.height, visible.height - 40)
        )
        window.styleMask.insert(.resizable)
        window.minSize = minimum
        window.maxSize = maximum
        var frame = window.frame
        if frame.size.width > maximum.width { frame.size.width = maximum.width }
        if frame.size.height > maximum.height { frame.size.height = maximum.height }
        if frame != window.frame { window.setFrame(frame, display: true) }
    }
}

    private func constrainMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.isVisible }),
              let screen = window.screen ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        let minimum = CGSize(width: 320, height: 256)
        let maximum = CGSize(
            width: max(minimum.width, visible.width - 40),
            height: max(minimum.height, visible.height - 40)
        )
        window.styleMask.insert(.resizable)
        window.minSize = minimum
        window.maxSize = maximum
        let current = window.frame.size
        guard current.width > maximum.width || current.height > maximum.height else { return }
        var frame = window.frame
        frame.size.width = min(current.width, maximum.width)
        frame.size.height = min(current.height, maximum.height)
        window.setFrame(frame, display: true)
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
