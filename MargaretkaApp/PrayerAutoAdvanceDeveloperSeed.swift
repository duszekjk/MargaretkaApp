import Foundation

#if DEBUG
extension PrayerAutoAdvanceCoreMLState {
    func installBundledDeveloperSeed() throws {
        guard model == nil else { return }
        guard let source = Bundle.main.url(forResource: "PrayerAutoAdvance", withExtension: "mlmodelc") else {
            throw PrayerAutoAdvanceDeveloperSeedError.missingBundledModel
        }

        let bundled = try PrayerAutoAdvanceCoreMLModel(compiledURL: source)
        guard let modelVersion = bundled.declaredModelVersion else {
            throw PrayerAutoAdvanceDeveloperSeedError.missingModelVersion
        }
        guard let schemaVersion = bundled.declaredFeatureSchemaVersion else {
            throw PrayerAutoAdvanceDeveloperSeedError.missingFeatureSchemaVersion
        }
        guard schemaVersion == PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion else {
            throw PrayerAutoAdvanceDeveloperSeedError.incompatibleFeatureSchema(
                found: schemaVersion,
                expected: PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion
            )
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: modelURL)
        model = try PrayerAutoAdvanceCoreMLModel(compiledURL: modelURL)

        let now = Date()
        metadata = PrayerAutoAdvanceLocalMetadata(
            baseModelVersion: modelVersion,
            featureSchemaVersion: schemaVersion,
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

enum PrayerAutoAdvanceDeveloperSeedError: LocalizedError {
    case missingBundledModel
    case missingModelVersion
    case missingFeatureSchemaVersion
    case incompatibleFeatureSchema(found: Int, expected: Int)

    var errorDescription: String? {
        switch self {
        case .missingBundledModel:
            "Brak skompilowanego PrayerAutoAdvance.mlmodelc w bundle aplikacji."
        case .missingModelVersion:
            "Model w bundle nie zawiera metadanej modelVersion. Wygeneruj go ponownie aktualnym skryptem."
        case .missingFeatureSchemaVersion:
            "Model w bundle nie zawiera metadanej featureSchemaVersion. Wygeneruj go ponownie aktualnym skryptem."
        case let .incompatibleFeatureSchema(found, expected):
            "Model w bundle ma schema v\(found), ale aplikacja oczekuje schema v\(expected). Usuń starą kopię modelu z targetu i dodaj aktualnie wygenerowany plik."
        }
    }
}
#endif
