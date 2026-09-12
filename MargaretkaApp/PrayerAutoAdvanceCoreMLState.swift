import Foundation
internal import Combine

@MainActor
final class PrayerAutoAdvanceCoreMLState: ObservableObject {
    static let shared = PrayerAutoAdvanceCoreMLState()

    @Published var model: PrayerAutoAdvanceCoreMLModel?
    @Published var metadata: PrayerAutoAdvanceLocalMetadata?
    @Published var timingHistory = PrayerAutoAdvanceTimingHistory()
    @Published var validationStore = PrayerAutoAdvanceValidationStore()
    @Published var isDownloading = false
    @Published var isTraining = false
    @Published var isTrainingPipelineBusy = false
    @Published var lastError: String?
    @Published var lastTrainingEvent: String?
    @Published var queuedTrainingPageCount = 0
    @Published var trainingQueueProgressCompleted = 0
    @Published var trainingQueueProgressTotal = 0
    @Published var storedTrainingPageCount = 0
    @Published var replayTrainingPageCount = 0
    @Published var groupedTrainingPageCount = 0
    @Published private(set) var trainingTrace: [String] = []

    var pendingTrainingPages: [PrayerAutoAdvanceDeferredTrainingPage] = []
    var trainingQueueTask: Task<Void, Never>?
    var trainingWorkEnqueued = 0
    var trainingWorkCompleted = 0
    var scheduledTrainingCaptureCount = 0
    var trainingAtPrayerEndRequested = false
    var groupedTrainingTask: Task<Void, Never>?

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
    var validationURL: URL { directory.appendingPathComponent("validation.json") }
    var pendingTrainingDirectory: URL {
        directory.appendingPathComponent("PendingTrainingPages", isDirectory: true)
    }
    var replayTrainingDirectory: URL {
        directory.appendingPathComponent("ReplayTrainingPages", isDirectory: true)
    }

    var hasModel: Bool { model != nil }
    var hasQueuedTrainingWork: Bool {
        scheduledTrainingCaptureCount > 0
            || !pendingTrainingPages.isEmpty
            || trainingQueueTask != nil
            || groupedTrainingTask != nil
    }

    private init() {
        PrayerAutoAdvanceCoreMLDiskState.load(self)
        storedTrainingPageCount = PrayerAutoAdvancePendingTrainingStore.pageCount(
            in: pendingTrainingDirectory,
            fileManager: fileManager
        )
        replayTrainingPageCount = PrayerAutoAdvancePendingTrainingStore.pageCount(
            in: replayTrainingDirectory,
            fileManager: fileManager
        )
    }

    func recordTrainingTrace(_ message: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        trainingTrace.append("[\(formatter.string(from: Date()))] \(message)")
        if trainingTrace.count > 100 {
            trainingTrace.removeFirst(trainingTrace.count - 100)
        }
    }
}
