import SwiftUI

#if os(macOS)
/// Material fallback used only when compiling the app for macOS versions
/// predating the system Liquid Glass API.
@available(macOS 15.0, *)
extension View {
    func prayerFlowLegacyGlass(_ tint: Color) -> some View {
        background(.ultraThinMaterial).tint(tint)
    }
}
#endif
