import Foundation
internal import Combine

@MainActor
final class PrayerAutoAdvanceCoreMLState: ObservableObject {
    static let shared = PrayerAutoAdvanceCoreMLState()

    @Published var model: PrayerAutoAdvanceCoreMLModel?
    @Published var metadata: PrayerAutoAdvanceLocalMetadata?
    @Published var timingHistory = PrayerAutoAdvanceTimingHistory()
    @Published var isDownloading = false
    @Published var isTraining = false
    @Published var lastError: String?
    @Published var lastTrainingEvent: String?

    let fileManager = FileManager.default

    var directory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrayerAutoAdvanceCoreML", isDirectory: true)
    }

    var modelURL: URL {
        directory.appendingPathComponent("Personalized.mlmodelc", isDirectory: true)
    }

    var metadataURL: URL { directory.appendingPathComponent("metadata.json") }
    var timingURL: URL { directory.appendingPathComponent("timing.json") }

    var hasModel: Bool { model != nil }

    private init() {
        PrayerAutoAdvanceCoreMLDiskState.load(self)
    }
}
