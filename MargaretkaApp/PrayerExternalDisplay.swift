import SwiftUI

@MainActor
final class PrayerExternalDisplayStore: ObservableObject {
    static let shared = PrayerExternalDisplayStore()

    @Published private(set) var page: PrayerExternalDisplayPage?

    private init() {}

    func update(
        displayIndex: Int,
        steps: [PrayerFlowStep],
        prayersByID: [UUID: Prayer]
    ) {
        let stepIndex = displayIndex - 1
        guard steps.indices.contains(stepIndex) else {
            page = nil
            return
        }

        let step = steps[stepIndex]
        let pageID = "\(stepIndex):\(step.prayerID.uuidString):\(step.offlineCard?.id.uuidString ?? "prayer")"

        if let card = step.offlineCard {
            page = .breviary(id: pageID, card: card)
        } else if let prayer = prayersByID[step.prayerID] {
            page = .prayer(id: pageID, name: prayer.name, text: prayer.text)
        } else {
            page = nil
        }
    }

    func clear() {
        page = nil
    }
}

enum PrayerExternalDisplayPage {
    case breviary(id: String, card: OfflineBreviaryCard)
    case prayer(id: String, name: String, text: String)

    var id: String {
        switch self {
        case .breviary(let id, _), .prayer(let id, _, _):
            return id
        }
    }
}

#if os(iOS)
import UIKit

private extension UISceneSession.Role {
    var isPrayerExternalDisplay: Bool {
        self == .windowExternalDisplay || self == .windowExternalDisplayNonInteractive
    }
}

extension AppDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        guard connectingSceneSession.role.isPrayerExternalDisplay else {
            return connectingSceneSession.configuration
        }

        let configuration = UISceneConfiguration(
            name: "Prayer External Display",
            sessionRole: connectingSceneSession.role
        )
        configuration.sceneClass = UIWindowScene.self
        configuration.delegateClass = PrayerExternalDisplaySceneDelegate.self
        return configuration
    }
}

final class PrayerExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard session.role.isPrayerExternalDisplay,
              let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let hostingController = UIHostingController(rootView: PrayerExternalDisplayView())
        hostingController.view.backgroundColor = .black
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()
    }
}

private struct PrayerExternalDisplayView: View {
    @ObservedObject private var store = PrayerExternalDisplayStore.shared

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = max(24, proxy.size.width * 0.035)
            let verticalPadding = max(24, proxy.size.height * 0.035)
            let availableSize = CGSize(
                width: max(1, proxy.size.width - horizontalPadding * 2),
                height: max(1, proxy.size.height - verticalPadding * 2)
            )

            ZStack {
                Color.black

                if let page = store.page {
                    FittedExternalPrayerPage(page: page, availableSize: availableSize)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .id(page.id)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

private struct FittedExternalPrayerPage: View {
    let page: PrayerExternalDisplayPage
    let availableSize: CGSize

    @State private var fontSize: CGFloat = 64

    var body: some View {
        externalPrayerContent
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: availableSize.width, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ExternalPrayerContentSizeKey.self,
                        value: proxy.size
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center
            )
            .onAppear(perform: resetFontSize)
            .onChange(of: availableSize) { _, _ in resetFontSize() }
            .onPreferenceChange(ExternalPrayerContentSizeKey.self, perform: fitFont)
    }

    @ViewBuilder
    private var externalPrayerContent: some View {
        switch page {
        case .breviary(_, let card):
            BreviaryPrayerCardText(
                card: card,
                maxHeight: Double.greatestFiniteMagnitude
            )
        case .prayer(_, let name, let text):
            VStack {
                Text(name)
                    .foregroundStyle(.white)
                    .font(.footnote)
                Text(text)
            }
        }
    }

    private var maximumFontSize: CGFloat {
        min(
            max(48, availableSize.height * 0.5),
            max(48, availableSize.width * 0.25),
            420
        )
    }

    private func resetFontSize() {
        fontSize = maximumFontSize
    }

    private func fitFont(_ measuredSize: CGSize) {
        guard measuredSize.width > 0,
              measuredSize.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else { return }

        let widthScale = availableSize.width / measuredSize.width
        let heightScale = availableSize.height / measuredSize.height
        let fitScale = min(widthScale, heightScale)

        let target: CGFloat
        if fitScale < 0.995 {
            target = max(12, fontSize * fitScale * 0.985)
        } else if fitScale > 1.025, fontSize < maximumFontSize {
            target = min(maximumFontSize, fontSize * min(fitScale * 0.985, 1.2))
        } else {
            return
        }

        guard abs(target - fontSize) > 0.5 else { return }
        fontSize = target
    }
}

private struct ExternalPrayerContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
#endif
