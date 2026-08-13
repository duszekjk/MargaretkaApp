import Foundation

@MainActor
enum PrayerAutoAdvanceLocalReset {
    static func run(state: PrayerAutoAdvanceCoreMLState = .shared) throws {
        let directory = state.directory
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        state.model = nil
        state.metadata = nil
        state.timingHistory = PrayerAutoAdvanceTimingHistory()
        state.lastError = nil
    }
}
