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
    @Published private(set) var microphoneActivityLevel: Double = 0
    @Published private(set) var microphoneSignalActive = false
    @Published private(set) var trainingTrace: [String] = []

    var pendingTrainingPages: [PrayerAutoAdvanceDeferredTrainingPage] = []
    var trainingQueueTask: Task<Void, Never>?
    var trainingWorkEnqueued = 0
    var trainingWorkCompleted = 0
    var scheduledTrainingCaptureCount = 0
    var trainingAtPrayerEndRequested = false
    var groupedTrainingTask: Task<Void, Never>?

    private var lastMicrophoneTranscript = ""
    private var microphoneActiveUntil = Date.distantPast
    private var microphoneProbeHistory: [Double] = []
    private static let microphoneProbeHistoryLimit = 12

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

    func updateMicrophoneActivity(
        transcript: String,
        firstSample: Float,
        lastSample: Float,
        at date: Date
    ) {
        let transcriptChanged = !transcript.isEmpty && transcript != lastMicrophoneTranscript
        lastMicrophoneTranscript = transcript

        microphoneProbeHistory.append(Double(firstSample))
        microphoneProbeHistory.append(Double(lastSample))
        if microphoneProbeHistory.count > Self.microphoneProbeHistoryLimit {
            microphoneProbeHistory.removeFirst(
                microphoneProbeHistory.count - Self.microphoneProbeHistoryLimit
            )
        }

        let peak = microphoneProbeHistory.map(abs).max() ?? 0
        let minimum = microphoneProbeHistory.min() ?? 0
        let maximum = microphoneProbeHistory.max() ?? 0
        let temporalVariation = maximum - minimum

        // The history spans roughly 3 seconds (two scalar samples every 0.5 s).
        // This is intentionally a coarse liveness check, not audio analysis.
        let audioLooksLive = peak >= 0.006 && temporalVariation >= 0.0015
        if transcriptChanged || audioLooksLive {
            microphoneActiveUntil = date.addingTimeInterval(transcriptChanged ? 1.1 : 0.8)
        }

        let normalizedLevel = min(max((peak - 0.003) / 0.035, 0), 1)
        if normalizedLevel >= microphoneActivityLevel {
            microphoneActivityLevel = microphoneActivityLevel * 0.2 + normalizedLevel * 0.8
        } else {
            microphoneActivityLevel = microphoneActivityLevel * 0.78 + normalizedLevel * 0.22
        }
        if microphoneActivityLevel < 0.01 { microphoneActivityLevel = 0 }
        microphoneSignalActive = date <= microphoneActiveUntil
    }

    func resetMicrophoneActivity() {
        microphoneActivityLevel = 0
        microphoneSignalActive = false
        microphoneActiveUntil = .distantPast
        microphoneProbeHistory.removeAll(keepingCapacity: true)
        lastMicrophoneTranscript = ""
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
