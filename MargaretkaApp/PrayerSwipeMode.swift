import SwiftUI

enum PrayerSwipeMode: String, CaseIterable, Identifiable {
    case vertical
    case horizontal
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical:
            return "W górę"
        case .horizontal:
            return "W prawo"
        case .both:
            return "Oba"
        }
    }
}

enum PrayerSwipeDirection {
    case up
    case right
    case down
    case left

    var isForward: Bool {
        switch self {
        case .up, .right:
            return true
        case .down, .left:
            return false
        }
    }
}
