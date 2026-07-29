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
internal import UniformTypeIdentifiers

#if os(iOS) || os(tvOS) || os(visionOS)
private typealias PlatformAppDelegate = UIApplicationDelegate
#else
private typealias PlatformAppDelegate = NSApplicationDelegate
#endif

#if os(macOS) || os(iOS)
enum AppMenuCatalog {
    static var entries: [PrayerTargetCategory: [(UUID, String)]] = [:]

    static func update(_ targets: [Priest]) {
        entries = Dictionary(uniqueKeysWithValues: PrayerTargetCategory.allCases.map { category in
            (category, targets.filter { $0.category == category }.map { ($0.id, $0.displayName) })
        })
        NotificationCenter.default.post(name: .margaretkaMenuNeedsRefresh, object: nil)
#if os(iOS)
        UIMenuSystem.main.setNeedsRebuild()
#endif
    }
}

#endif

#if os(macOS)
private final class MacMenuTarget: NSObject, NSMenuItemValidation {
    private func newTarget(_ category: PrayerTargetCategory) {
        NotificationCenter.default.post(name: .margaretkaNewPerson, object: category)
    }
    @objc func newPriest() { newTarget(.priest) }
    @objc func newPerson() { newTarget(.person) }
    @objc func newPrayer() { newTarget(.prayer) }
    @objc func settings() { NotificationCenter.default.post(name: .margaretkaSettings, object: nil) }
    @objc func importPrayers() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .epub]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            NotificationCenter.default.post(name: .margaretkaImportFile, object: url)
        }
    }
    @objc func exportData() { NotificationCenter.default.post(name: .margaretkaImport, object: "export") }
    @objc func backupData() { NotificationCenter.default.post(name: .margaretkaImport, object: "backup") }
    @objc func restoreBackup() { NotificationCenter.default.post(name: .margaretkaImport, object: "restore") }
    @objc func sharePrayers() { NotificationCenter.default.post(name: .margaretkaImport, object: "share") }
    @objc func statistics() { NotificationCenter.default.post(name: .margaretkaStatistics, object: nil) }
    @objc func about() { NotificationCenter.default.post(name: .margaretkaAbout, object: nil) }
    @objc func howTo() { NotificationCenter.default.post(name: .margaretkaHowTo, object: nil) }
    @objc func syncNow() { NotificationCenter.default.post(name: .margaretkaSync, object: nil) }
    @objc func syncSettings() { NotificationCenter.default.post(name: .margaretkaSyncSettings, object: nil) }
    @objc func prayerList() { NotificationCenter.default.post(name: .margaretkaPrayerList, object: nil) }
    @objc func toggleCompact() { NotificationCenter.default.post(name: .margaretkaToggleCompact, object: nil) }
    @objc func selectTarget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        NotificationCenter.default.post(name: .margaretkaSelectTarget, object: id)
    }
    @objc func editTarget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        NotificationCenter.default.post(name: .margaretkaEditTarget, object: id)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(syncNow) {
            return SyncService.shared.isSignedIn && !SyncService.shared.isWorking
        }
        return true
    }
}
#endif

final class AppDelegate: NSObject, PlatformAppDelegate, UNUserNotificationCenterDelegate {
#if os(macOS)
    private let menuTarget = MacMenuTarget()
#endif
#if os(iOS)
    private enum IPadMenuIdentifier {
        static let file = UIMenu.Identifier("com.duszekjk.margaretka.file")
        static let priests = UIMenu.Identifier("com.duszekjk.margaretka.priests")
        static let people = UIMenu.Identifier("com.duszekjk.margaretka.people")
        static let prayers = UIMenu.Identifier("com.duszekjk.margaretka.prayers")
        static let sync = UIMenu.Identifier("com.duszekjk.margaretka.sync")
        static let statistics = UIMenu.Identifier("com.duszekjk.margaretka.statistics")
        static let view = UIMenu.Identifier("com.duszekjk.margaretka.view")
        static let help = UIMenu.Identifier("com.duszekjk.margaretka.help")
    }

    @objc private func openNewPriest() { NotificationCenter.default.post(name: .margaretkaNewPerson, object: PrayerTargetCategory.priest) }
    @objc private func openNewPerson() { NotificationCenter.default.post(name: .margaretkaNewPerson, object: nil) }
    @objc private func openNewPrayer() { NotificationCenter.default.post(name: .margaretkaNewPerson, object: PrayerTargetCategory.prayer) }
    @objc private func openSettings() { NotificationCenter.default.post(name: .margaretkaSettings, object: nil) }
    @objc private func openImport() { NotificationCenter.default.post(name: .margaretkaImport, object: "import") }
    @objc private func openExport() { NotificationCenter.default.post(name: .margaretkaImport, object: "export") }
    @objc private func openBackup() { NotificationCenter.default.post(name: .margaretkaImport, object: "backup") }
    @objc private func openRestore() { NotificationCenter.default.post(name: .margaretkaImport, object: "restore") }
    @objc private func openSharePrayers() { NotificationCenter.default.post(name: .margaretkaImport, object: "share") }
    @objc private func openStatistics() { NotificationCenter.default.post(name: .margaretkaStatistics, object: nil) }
    @objc private func openAbout() { NotificationCenter.default.post(name: .margaretkaAbout, object: nil) }
    @objc private func openHowTo() { NotificationCenter.default.post(name: .margaretkaHowTo, object: nil) }
    @objc private func openSync() { NotificationCenter.default.post(name: .margaretkaSync, object: nil) }
    @objc private func openSyncSettings() { NotificationCenter.default.post(name: .margaretkaSyncSettings, object: nil) }
    @objc private func openPrayerList() { NotificationCenter.default.post(name: .margaretkaPrayerList, object: nil) }
    @objc private func toggleCompact() { NotificationCenter.default.post(name: .margaretkaToggleCompact, object: nil) }
    @objc private func selectTarget(_ command: UICommand) {
        guard let rawID = command.propertyList as? String, let id = UUID(uuidString: rawID) else { return }
        NotificationCenter.default.post(name: .margaretkaSelectTarget, object: id)
    }
    @objc private func editTarget(_ command: UICommand) {
        guard let rawID = command.propertyList as? String, let id = UUID(uuidString: rawID) else { return }
        NotificationCenter.default.post(name: .margaretkaEditTarget, object: id)
    }
    @objc private func menuSectionTitle() {}
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
#if os(iOS)
    func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == .main else { return }
        let customMenus = [
            IPadMenuIdentifier.file,
            IPadMenuIdentifier.priests,
            IPadMenuIdentifier.people,
            IPadMenuIdentifier.prayers,
            IPadMenuIdentifier.sync,
            IPadMenuIdentifier.statistics,
            IPadMenuIdentifier.view,
            IPadMenuIdentifier.help
        ]
        for menu in customMenus + [.file, .edit, .view, .window, .help] {
            builder.remove(menu: menu)
        }

        let addPerson = UIKeyCommand(input: "n", modifierFlags: .command, action: #selector(openNewPerson))
        addPerson.title = "Dodaj osobę do modlitwy"
        let syncCommand = UICommand(title: "Synchronizuj teraz", action: #selector(openSync))
        if !SyncService.shared.isSignedIn { syncCommand.attributes = [.disabled] }
        let fileMenu = UIMenu(title: "Plik", identifier: IPadMenuIdentifier.file, children: [
            addPerson,
            UICommand(title: "Importuj modlitwy", action: #selector(openImport)),
            UICommand(title: "Utwórz kopię zapasową", action: #selector(openBackup)),
            UICommand(title: "Przywróć kopię zapasową", action: #selector(openRestore)),
            UICommand(title: "Eksportuj dane", action: #selector(openExport)),
            UICommand(title: "Udostępnij modlitwy", action: #selector(openSharePrayers))
        ])
        let priestsMenu = UIMenu(title: "Księża", identifier: IPadMenuIdentifier.priests, children: [
            iPadTargetSection("Pomódl się", category: .priest, action: #selector(selectTarget(_:))),
            iPadTargetSection("Edytuj", category: .priest, action: #selector(editTarget(_:))),
            UICommand(title: "Dodaj księdza", action: #selector(openNewPriest))
        ])
        let peopleMenu = UIMenu(title: "Osoby", identifier: IPadMenuIdentifier.people, children: [
            iPadTargetSection("Pomódl się", category: .person, action: #selector(selectTarget(_:))),
            iPadTargetSection("Edytuj", category: .person, action: #selector(editTarget(_:))),
            UICommand(title: "Dodaj osobę", action: #selector(openNewPerson))
        ])
        let prayersMenu = UIMenu(title: "Modlitwy", identifier: IPadMenuIdentifier.prayers, children: [
            iPadTargetSection("Pomódl się", category: .prayer, action: #selector(selectTarget(_:))),
            iPadTargetSection("Edytuj", category: .prayer, action: #selector(editTarget(_:))),
            UICommand(title: "Dodaj modlitwę złożoną", action: #selector(openNewPrayer))
        ])
        let syncMenu = UIMenu(title: "Synchronizacja", identifier: IPadMenuIdentifier.sync, children: [
            UICommand(title: "Zaloguj przez Apple", action: #selector(openSyncSettings)), syncCommand
        ])
        let statisticsMenu = UIMenu(title: "Statystyki", identifier: IPadMenuIdentifier.statistics, children: [
            UICommand(title: "Otwórz statystyki", action: #selector(openStatistics))
        ])
        let viewMenu = UIMenu(title: "Widok", identifier: IPadMenuIdentifier.view, children: [
            UICommand(title: "Compact view", action: #selector(toggleCompact))
        ])
        let helpMenu = UIMenu(title: "Pomoc", identifier: IPadMenuIdentifier.help, children: [
            UICommand(title: "Czym jest Margaretka?", action: #selector(openAbout)),
            UICommand(title: "Jak się modlić?", action: #selector(openHowTo))
        ])
        builder.insertSibling(fileMenu, afterMenu: .application)
        builder.insertSibling(priestsMenu, afterMenu: IPadMenuIdentifier.file)
        builder.insertSibling(peopleMenu, afterMenu: IPadMenuIdentifier.priests)
        builder.insertSibling(prayersMenu, afterMenu: IPadMenuIdentifier.people)
        builder.insertSibling(syncMenu, afterMenu: IPadMenuIdentifier.prayers)
        builder.insertSibling(statisticsMenu, afterMenu: IPadMenuIdentifier.sync)
        builder.insertSibling(viewMenu, afterMenu: IPadMenuIdentifier.statistics)
        builder.insertSibling(helpMenu, afterMenu: IPadMenuIdentifier.view)
    }

    private func iPadTargetSection(
        _ title: String,
        category: PrayerTargetCategory,
        action: Selector
    ) -> UIMenu {
        let entries = AppMenuCatalog.entries[category] ?? []
        let commands: [UIMenuElement]
        if entries.isEmpty {
            let empty = UICommand(title: "Brak zapisanych elementów", action: #selector(menuSectionTitle))
            empty.attributes = [.disabled]
            commands = [empty]
        } else {
            commands = entries.map { id, displayName in
                UICommand(
                    title: displayName,
                    image: nil,
                    action: action,
                    propertyList: id.uuidString
                )
            }
        }
        return UIMenu(title: title, options: .displayInline, children: commands)
    }
#endif
#else
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        cleanStalePreferenceTemporaryFiles()
        cleanLegacyWebCachesIfNeeded()
        configureMargaretkaMenu()
        NotificationCenter.default.addObserver(
            forName: .margaretkaMenuNeedsRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureMargaretkaMenu()
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureMargaretkaMenu()
            self?.constrainMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.constrainMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.configureMargaretkaMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.configureMargaretkaMenu()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.configureMargaretkaMenu()
        }
    }
#endif

#if os(macOS)
    func configureMargaretkaMenu() {
        let menu = NSMenu()
        let file = NSMenu(title: "Plik")
        file.addItem(withTitle: "Dodaj osobę do modlitwy", action: #selector(MacMenuTarget.newPerson), keyEquivalent: "n").target = menuTarget
        file.addItem(withTitle: "Importuj modlitwy", action: #selector(MacMenuTarget.importPrayers), keyEquivalent: "").target = menuTarget
        file.addItem(withTitle: "Utwórz kopię zapasową", action: #selector(MacMenuTarget.backupData), keyEquivalent: "").target = menuTarget
        file.addItem(withTitle: "Przywróć kopię zapasową", action: #selector(MacMenuTarget.restoreBackup), keyEquivalent: "").target = menuTarget
        file.addItem(withTitle: "Eksportuj dane", action: #selector(MacMenuTarget.exportData), keyEquivalent: "").target = menuTarget
        file.addItem(withTitle: "Udostępnij modlitwy", action: #selector(MacMenuTarget.sharePrayers), keyEquivalent: "").target = menuTarget
        file.addItem(.separator())
        file.addItem(withTitle: "Zakończ aplikację", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp

        let view = NSMenu(title: "Widok")
        view.addItem(withTitle: "Pełny ekran", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f").target = nil

        let help = NSMenu(title: "Pomoc")
        help.addItem(withTitle: "O aplikacji Margaretka", action: #selector(MacMenuTarget.about), keyEquivalent: "").target = menuTarget
        help.addItem(withTitle: "Czym jest Margaretka?", action: #selector(MacMenuTarget.about), keyEquivalent: "").target = menuTarget
        help.addItem(withTitle: "Jak się modlić?", action: #selector(MacMenuTarget.howTo), keyEquivalent: "").target = menuTarget

        let customMenus: [(String, NSMenu)] = [
            ("Plik", file),
            ("Księża", NSMenu(title: "Księża")),
            ("Osoby", NSMenu(title: "Osoby")),
            ("Modlitwy", NSMenu(title: "Modlitwy")),
            ("Synchronizacja", NSMenu(title: "Synchronizacja")),
            ("Statystyki", NSMenu(title: "Statystyki")),
            ("Widok", view),
            ("Pomoc", help)
        ]
        let praySection = NSMenuItem(title: "Pomódl się", action: nil, keyEquivalent: "")
        praySection.isEnabled = false
        customMenus[1].1.addItem(praySection)
        addTargetItems(
            to: customMenus[1].1,
            category: .priest,
            action: #selector(MacMenuTarget.selectTarget(_:))
        )
        customMenus[1].1.addItem(.separator())
        let editSection = NSMenuItem(title: "Edytuj", action: nil, keyEquivalent: "")
        editSection.isEnabled = false
        customMenus[1].1.addItem(editSection)
        addTargetItems(
            to: customMenus[1].1,
            category: .priest,
            action: #selector(MacMenuTarget.editTarget(_:))
        )
        customMenus[1].1.addItem(.separator())
        customMenus[1].1.addItem(withTitle: "Dodaj księdza", action: #selector(MacMenuTarget.newPriest), keyEquivalent: "").target = menuTarget
        addTargetSections(to: customMenus[2].1, category: .person)
        customMenus[2].1.addItem(withTitle: "Dodaj osobę", action: #selector(MacMenuTarget.newPerson), keyEquivalent: "").target = menuTarget
        addTargetSections(to: customMenus[3].1, category: .prayer)
        customMenus[3].1.addItem(withTitle: "Dodaj modlitwę", action: #selector(MacMenuTarget.newPrayer), keyEquivalent: "").target = menuTarget
        customMenus[3].1.addItem(withTitle: "Importuj modlitwy", action: #selector(MacMenuTarget.importPrayers), keyEquivalent: "").target = menuTarget
        customMenus[4].1.addItem(withTitle: "Zaloguj przez Apple", action: #selector(MacMenuTarget.syncSettings), keyEquivalent: "").target = menuTarget
        customMenus[4].1.addItem(withTitle: "Synchronizuj teraz", action: #selector(MacMenuTarget.syncNow), keyEquivalent: "").target = menuTarget
        customMenus[5].1.addItem(withTitle: "Otwórz statystyki", action: #selector(MacMenuTarget.statistics), keyEquivalent: "").target = menuTarget
        for (title, submenu) in customMenus {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            menu.addItem(item)
        }
        let settings = NSMenuItem(title: "Ustawienia Margaretki", action: #selector(MacMenuTarget.settings), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = [.command]
        settings.target = menuTarget
        view.addItem(settings)
        view.addItem(withTitle: "Compact view", action: #selector(MacMenuTarget.toggleCompact), keyEquivalent: "").target = menuTarget
        NSApp.mainMenu = menu
    }

    private func addTargetItems(to menu: NSMenu, category: PrayerTargetCategory, action: Selector = #selector(MacMenuTarget.selectTarget(_:))) {
        let items = AppMenuCatalog.entries[category] ?? []
        if items.isEmpty {
            menu.addItem(withTitle: "Brak zapisanych elementów", action: nil, keyEquivalent: "").isEnabled = false
        } else {
            for (id, title) in items {
                let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
                item.target = menuTarget
                item.representedObject = id
            }
        }
    }

    private func addTargetSections(to menu: NSMenu, category: PrayerTargetCategory) {
        let praySection = NSMenuItem(title: "Pomódl się", action: nil, keyEquivalent: "")
        praySection.isEnabled = false
        menu.addItem(praySection)
        addTargetItems(
            to: menu,
            category: category,
            action: #selector(MacMenuTarget.selectTarget(_:))
        )
        menu.addItem(.separator())
        let editSection = NSMenuItem(title: "Edytuj", action: nil, keyEquivalent: "")
        editSection.isEnabled = false
        menu.addItem(editSection)
        addTargetItems(
            to: menu,
            category: category,
            action: #selector(MacMenuTarget.editTarget(_:))
        )
        menu.addItem(.separator())
    }

    struct MacWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        if NSApp.mainMenu?.item(withTitle: "Księża") == nil {
            (NSApp.delegate as? AppDelegate)?.configureMargaretkaMenu()
        }
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
