#if os(iOS)
import SwiftUI

extension PrayerExternalDisplayRootView {
    @ViewBuilder
    func fullCanvasPageView(
        _ page: PrayerExternalDisplayPage,
        geometry: GeometryProxy
    ) -> some View {
        ViewThatFits(in: .vertical) {
            pageView(page, fontSize: 80, geometry: geometry)
            pageView(page, fontSize: 72, geometry: geometry)
            pageView(page, fontSize: 64, geometry: geometry)
            pageView(page, fontSize: 56, geometry: geometry)
            pageView(page, fontSize: 48, geometry: geometry)
            pageView(page, fontSize: 42, geometry: geometry)
            pageView(page, fontSize: 36, geometry: geometry)
            pageView(page, fontSize: 30, geometry: geometry)
            pageView(page, fontSize: 26, geometry: geometry)
            pageView(page, fontSize: 22, geometry: geometry)
        }
    }
}
#endif
