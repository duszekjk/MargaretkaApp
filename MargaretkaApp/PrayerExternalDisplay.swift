#if os(iOS)
import SwiftUI

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
