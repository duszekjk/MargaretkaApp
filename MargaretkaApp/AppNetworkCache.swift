import Foundation

enum AppNetworkCache {
    static let diskCapacity = 300_000
    private static let memoryCapacity = 64_000

    static func configure() {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "MargaretkaNetwork"
        )
    }

    static func clear() {
        URLCache.shared.removeAllCachedResponses()
    }
}
