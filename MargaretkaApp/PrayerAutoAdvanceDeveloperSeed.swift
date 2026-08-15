import Foundation

#if DEBUG
extension PrayerAutoAdvanceCoreMLState {
    func installBundledDeveloperSeed() throws {
        guard model == nil else { return }
        guard let source = Bundle.main.url(forResource: "PrayerAutoAdvance", withExtension: "mlmodelc") else {
            throw CocoaError(.fileNoSuchFile)
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: modelURL)
        model = try PrayerAutoAdvanceCoreMLModel(compiledURL: modelURL)

        let now = Date()
        metadata = PrayerAutoAdvanceLocalMetadata(
            baseModelVersion: 4,
            featureSchemaVersion: PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion,
            createdAt: now,
            lastUpdatedAt: now,
            trainingSessions: 0,
            trainedTransitions: 0
        )
        timingHistory = PrayerAutoAdvanceTimingHistory()
        validationStore = PrayerAutoAdvanceValidationStore()
        PrayerAutoAdvanceTrainingDiagnostics.shared.resetEpochHistory()
        try PrayerAutoAdvanceCoreMLDiskState.save(self)
    }
}
#endif
