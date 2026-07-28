codex conversation [20260728-macos] split PrayerFlowView background expression

Extract the GeometryReader-based background layer from the main PrayerFlowView
ZStack to reduce SwiftUI type-checking complexity without changing layout.
