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

extension AppDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        guard connectingSceneSession.role == .windowExternalDisplayNonInteractive else {
            return connectingSceneSession.configuration
        }

        let configuration = UISceneConfiguration(
            name: "Prayer External Display",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = PrayerExternalDisplaySceneDelegate.self
        return configuration
    }
}

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

        let hostingController = UIHostingController(
            rootView: PrayerExternalDisplayRootView(
                page: PrayerExternalDisplayStore.shared.currentPage
            )
        )
        hostingController.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = hostingController
        self.window = window
        self.hostingController = hostingController
        window.makeKeyAndVisible()

        pageObserver = NotificationCenter.default.addObserver(
            forName: PrayerExternalDisplayStore.pageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPage()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
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
