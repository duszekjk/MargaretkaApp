import Foundation

enum PrayerAutoAdvanceCoreMLDiskState {
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
    static func save(_ state: PrayerAutoAdvanceCoreMLState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try state.fileManager.createDirectory(at: state.directory, withIntermediateDirectories: true)
        if let metadata = state.metadata {
            try encoder.encode(metadata).write(to: state.metadataURL, options: .atomic)
        }
        try encoder.encode(state.timingHistory).write(to: state.timingURL, options: .atomic)
        try encoder.encode(state.validationStore).write(to: state.validationURL, options: .atomic)
    }
}
