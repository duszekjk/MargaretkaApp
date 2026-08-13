import Foundation

@MainActor
enum PrayerAutoAdvanceLocalReset {
    static func run(store: PrayerAutoAdvanceStore = .shared) throws {
        let directory = store.storageDirectory
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        store.clearLoadedState()
    }
}
