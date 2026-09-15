#if os(iOS)
import SwiftUI
import UIKit

@MainActor
final class PrayerExternalDisplayStore {
    static let shared = PrayerExternalDisplayStore()

    static let pageDidChange = Notification.Name("margaretka.externalDisplay.pageDidChange")

    private(set) var currentPage: PrayerExternalDisplayPage?

    private init() {}

    func update(displayIndex: Int, steps: [PrayerFlowStep], prayersByID: [UUID: Prayer]) {
        let stepIndex = displayIndex - 1
        guard steps.indices.contains(stepIndex) else {
            clear()
            return
        }

        let step = steps[stepIndex]
        if let card = step.offlineCard {
            currentPage = .breviary(card)
        } else if let prayer = prayersByID[step.prayerID] {
            currentPage = .prayer(name: prayer.name, text: prayer.text)
        } else {
            currentPage = nil
        }

        NotificationCenter.default.post(name: Self.pageDidChange, object: nil)
    }

    func clear() {
        currentPage = nil
        NotificationCenter.default.post(name: Self.pageDidChange, object: nil)
    }
}

enum PrayerExternalDisplayPage {
    case breviary(OfflineBreviaryCard)
    case prayer(name: String, text: String)
}

@MainActor
final class PrayerExternalDisplayController {
    static let shared = PrayerExternalDisplayController()

    private var legacyWindow: UIWindow?
    private var pageObserver: NSObjectProtocol?
    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var sceneOwnedScreens = Set<ObjectIdentifier>()
    private var isStarted = false

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true

        pageObserver = NotificationCenter.default.addObserver(
            forName: PrayerExternalDisplayStore.pageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLegacyWindow()
            }
        }

        connectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in
                self?.logScreenEvent("connected", screen: screen)
                self?.attachLegacyWindowIfNeeded()
            }
        }

        disconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in
                self?.logScreenEvent("disconnected", screen: screen)
                if self?.legacyWindow?.screen === screen {
                    self?.legacyWindow?.isHidden = true
                    self?.legacyWindow = nil
                }
                self?.attachLegacyWindowIfNeeded()
            }
        }

        logEnvironment()
        attachLegacyWindowIfNeeded()
    }

    func sceneDidConnect(screen: UIScreen) {
        sceneOwnedScreens.insert(ObjectIdentifier(screen))
        if legacyWindow?.screen === screen {
            legacyWindow?.isHidden = true
            legacyWindow = nil
        }
        print("[ExternalDisplay] scene owns screen bounds=\(screen.bounds)")
    }

    func sceneDidDisconnect(screen: UIScreen) {
        sceneOwnedScreens.remove(ObjectIdentifier(screen))
        attachLegacyWindowIfNeeded()
    }

    private func attachLegacyWindowIfNeeded() {
        guard legacyWindow == nil else {
            refreshLegacyWindow()
            return
        }

        guard let externalScreen = UIScreen.screens.first(where: { screen in
            screen !== UIScreen.main && !sceneOwnedScreens.contains(ObjectIdentifier(screen))
        }) else {
            return
        }

        let hostingController = UIHostingController(
            rootView: PrayerExternalDisplayRootView(
                page: PrayerExternalDisplayStore.shared.currentPage
            )
        )
        hostingController.view.backgroundColor = .black

        let window = UIWindow(frame: externalScreen.bounds)
        window.screen = externalScreen
        window.backgroundColor = .black
        window.rootViewController = hostingController
        window.isHidden = false
        legacyWindow = window

        print("[ExternalDisplay] legacy window active bounds=\(externalScreen.bounds)")
    }

    private func refreshLegacyWindow() {
        guard let window = legacyWindow else {
            attachLegacyWindowIfNeeded()
            return
        }

        let hostingController = UIHostingController(
            rootView: PrayerExternalDisplayRootView(
                page: PrayerExternalDisplayStore.shared.currentPage
            )
        )
        hostingController.view.backgroundColor = .black
        window.rootViewController = hostingController
    }

    private func logEnvironment() {
        let screens = UIScreen.screens.enumerated().map { index, screen in
            "#\(index)=\(screen.bounds)"
        }.joined(separator: ", ")
        print(
            "[ExternalDisplay] startup supportsMultipleScenes=\(UIApplication.shared.supportsMultipleScenes) " +
            "screens=\(UIScreen.screens.count) [\(screens)]"
        )
    }

    private func logScreenEvent(_ event: String, screen: UIScreen) {
        print(
            "[ExternalDisplay] screen \(event) bounds=\(screen.bounds) " +
            "totalScreens=\(UIScreen.screens.count)"
        )
    }
}

@objc(PrayerExternalDisplaySceneDelegate)
@MainActor
final class PrayerExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    private var hostingController: UIHostingController<PrayerExternalDisplayRootView>?
    private var pageObserver: NSObjectProtocol?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else { return }

        PrayerExternalDisplayController.shared.sceneDidConnect(screen: windowScene.screen)
        print("[ExternalDisplay] connected role=\(session.role.rawValue) screen=\(windowScene.screen.bounds)")

        let hostingController = UIHostingController(
            rootView: PrayerExternalDisplayRootView(
                page: PrayerExternalDisplayStore.shared.currentPage
            )
        )
        hostingController.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = hostingController

        self.hostingController = hostingController
        self.window = window

        pageObserver = NotificationCenter.default.addObserver(
            forName: PrayerExternalDisplayStore.pageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPage()
            }
        }

        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[ExternalDisplay] disconnected")
        if let windowScene = scene as? UIWindowScene {
            PrayerExternalDisplayController.shared.sceneDidDisconnect(screen: windowScene.screen)
        }
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
        }
        pageObserver = nil
        hostingController = nil
        window = nil
    }

    private func refreshPage() {
        hostingController?.rootView = PrayerExternalDisplayRootView(
            page: PrayerExternalDisplayStore.shared.currentPage
        )
    }
}

struct PrayerExternalDisplayRootView: View {
    let page: PrayerExternalDisplayPage?

    private var appDisplayName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        return "App"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let page {
                    ViewThatFits(in: .vertical) {
                        pageView(page, fontSize: 64, geometry: geometry)
                        pageView(page, fontSize: 56, geometry: geometry)
                        pageView(page, fontSize: 48, geometry: geometry)
                        pageView(page, fontSize: 42, geometry: geometry)
                        pageView(page, fontSize: 36, geometry: geometry)
                        pageView(page, fontSize: 30, geometry: geometry)
                        pageView(page, fontSize: 26, geometry: geometry)
                        pageView(page, fontSize: 22, geometry: geometry)
                    }
                    .padding(.horizontal, max(36, geometry.size.width * 0.055))
                    .padding(.vertical, max(28, geometry.size.height * 0.05))
                } else {
                    Text(appDisplayName)
                        .font(.system(size: min(76, max(42, geometry.size.width * 0.06)), weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func pageView(
        _ page: PrayerExternalDisplayPage,
        fontSize: CGFloat,
        geometry: GeometryProxy
    ) -> some View {
        switch page {
        case .breviary(let card):
            BreviaryPrayerCardText(card: card, maxHeight: geometry.size.height * 0.9)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .prayer(let name, let text):
            VStack(spacing: max(18, fontSize * 0.5)) {
                Text(name)
                    .font(.system(size: fontSize * 0.72, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
#endif
