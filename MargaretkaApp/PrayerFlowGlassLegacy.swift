import SwiftUI

#if os(macOS)
/// Material fallback used only when compiling the app for macOS versions
/// predating the system Liquid Glass API.
@available(macOS 15.0, *)
extension View {
    func prayerFlowLegacyGlass(_ tint: Color) -> some View {
        background(.ultraThinMaterial).tint(tint)
    }

    @available(macOS, introduced: 15.0, obsoleted: 26.0)
    func glassEffect() -> some View {
        background(.ultraThinMaterial)
    }

    @available(macOS, introduced: 15.0, obsoleted: 26.0)
    func glassEffectUnion(id: String, namespace: Namespace.ID) -> some View {
        background(.ultraThinMaterial)
    }
}

@available(macOS, introduced: 15.0, obsoleted: 26.0)
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder var body: some View {
        if #available(macOS 26.0, *) {
            SwiftUI.GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
#endif
