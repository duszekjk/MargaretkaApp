//
//  PrayerFlowLayoutComponents.swift
//  MargaretkaApp
//

import SwiftUI

struct PrayerFlowAdaptiveWidth: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
#if os(macOS)
        content.frame(maxWidth: .infinity)
#else
        content.frame(width: width)
#endif
    }
}

struct PrayerFlowCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
    }
}
