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

    var pendingTrainingPages: [PrayerAutoAdvanceDeferredTrainingPage] = []
    var trainingQueueTask: Task<Void, Never>?
    var trainingWorkEnqueued = 0
    var trainingWorkCompleted = 0

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

    var hasModel: Bool { model != nil }
    var hasQueuedTrainingWork: Bool { !pendingTrainingPages.isEmpty || trainingQueueTask != nil }

    private init() {
        PrayerAutoAdvanceCoreMLDiskState.load(self)
    }
}
