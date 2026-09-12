import Foundation

enum PrayerAutoAdvanceCoreMLDiskState {
    struct Snapshot: Sendable {
        let metadata: PrayerAutoAdvanceLocalMetadata?
        let timingHistory: PrayerAutoAdvanceTimingHistory
        let validationStore: PrayerAutoAdvanceValidationStore
        let directory: URL
        let metadataURL: URL
        let timingURL: URL
        let validationURL: URL
    }

    @MainActor
    static func load(_ state: PrayerAutoAdvanceCoreMLState) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let metadataData = try? Data(contentsOf: state.metadataURL),
              let metadata = try? decoder.decode(PrayerAutoAdvanceLocalMetadata.self, from: metadataData),
              metadata.featureSchemaVersion == PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion else {
            if state.fileManager.fileExists(atPath: state.directory.path) {
                try? state.fileManager.removeItem(at: state.directory)
            }
            state.model = nil
            state.metadata = nil
            state.timingHistory = PrayerAutoAdvanceTimingHistory()
            state.validationStore = PrayerAutoAdvanceValidationStore()
            PrayerAutoAdvanceTrainingDiagnostics.shared.resetEpochHistory()
            return
        }

        state.metadata = metadata
        if let model = try? PrayerAutoAdvanceCoreMLModel(compiledURL: state.modelURL) {
            state.model = model
        }
        if let data = try? Data(contentsOf: state.timingURL),
           let history = try? decoder.decode(PrayerAutoAdvanceTimingHistory.self, from: data) {
            state.timingHistory = history
        }
        if let data = try? Data(contentsOf: state.validationURL),
           let validation = try? decoder.decode(PrayerAutoAdvanceValidationStore.self, from: data) {
            state.validationStore = validation
        }
    }

    @MainActor
    static func snapshot(_ state: PrayerAutoAdvanceCoreMLState) -> Snapshot {
        Snapshot(
            metadata: state.metadata,
            timingHistory: state.timingHistory,
            validationStore: state.validationStore,
            directory: state.directory,
            metadataURL: state.metadataURL,
            timingURL: state.timingURL,
            validationURL: state.validationURL
        )
    }

    /// Hot-path persistence for training/validation. JSON encoding and atomic file
    /// writes can be expensive once the validation store contains full V12 feature
    /// vectors, so never execute them on MainActor.
    @MainActor
    static func saveInBackground(_ state: PrayerAutoAdvanceCoreMLState) async throws {
        let value = snapshot(state)
        try await Task.detached(priority: .utility) {
            try write(value)
        }.value
    }

    /// Synchronous variant retained for explicit settings/developer actions where
    /// callers already expect a throwing synchronous API.
    @MainActor
    static func save(_ state: PrayerAutoAdvanceCoreMLState) throws {
        try write(snapshot(state))
    }

    nonisolated private static func write(_ value: Snapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: value.directory, withIntermediateDirectories: true)
        if let metadata = value.metadata {
            try encoder.encode(metadata).write(to: value.metadataURL, options: .atomic)
        }
        try encoder.encode(value.timingHistory).write(to: value.timingURL, options: .atomic)
        try encoder.encode(value.validationStore).write(to: value.validationURL, options: .atomic)
    }
}
