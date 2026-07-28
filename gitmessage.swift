codex conversation [20260728-swiftui] simplify PrayerFlow body frame

Replace platform-conditional root frame branches with one flexible frame to
avoid SwiftUI's opaque-body diagnostic while preserving adaptive layout.
