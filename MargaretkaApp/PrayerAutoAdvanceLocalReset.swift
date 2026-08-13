import Foundation

@MainActor
enum PrayerAutoAdvanceLocalReset {
    static func run(store: PrayerAutoAdvanceStore = .shared) throws {
        for url in [store.modelURL, store.metadataURL] {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try Data().write(to: url, options: .atomic)
        }
        store.clearLoadedState()
    }
}
