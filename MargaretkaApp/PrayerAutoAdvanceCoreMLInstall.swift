import Foundation

enum PrayerAutoAdvanceCoreMLInstall {
    @MainActor
    static func run(
        _ downloaded: PrayerAutoAdvanceDownloadedBase,
        state: PrayerAutoAdvanceCoreMLState
    ) throws {
        if state.fileManager.fileExists(atPath: state.modelURL.path) {
            do {
                state.model = try PrayerAutoAdvanceCoreMLModel(compiledURL: state.modelURL)
                return
            } catch {
                try state.fileManager.removeItem(at: state.modelURL)
            }
        }

        try state.fileManager.createDirectory(at: state.directory, withIntermediateDirectories: true)
        let archive = state.fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("aar")
        let staging = state.directory.appendingPathComponent("Incoming.mlmodelc", isDirectory: true)
        if state.fileManager.fileExists(atPath: staging.path) {
            try state.fileManager.removeItem(at: staging)
        }
        defer {
            try? state.fileManager.removeItem(at: archive)
            try? state.fileManager.removeItem(at: staging)
        }

        try downloaded.archiveData.write(to: archive, options: .atomic)
        try PrayerAutoAdvanceArchive.extractArchive(at: archive, to: staging)
        let stagedModel = try PrayerAutoAdvanceCoreMLModel(compiledURL: staging)
        guard stagedModel.declaredModelVersion == downloaded.manifest.modelVersion,
              stagedModel.declaredFeatureSchemaVersion == downloaded.manifest.featureSchemaVersion else {
            throw InstallError.manifestMetadataMismatch
        }
        try state.fileManager.moveItem(at: staging, to: state.modelURL)
        state.model = try PrayerAutoAdvanceCoreMLModel(compiledURL: state.modelURL)

        let now = Date()
        state.metadata = PrayerAutoAdvanceLocalMetadata(
            baseModelVersion: downloaded.manifest.modelVersion,
            featureSchemaVersion: downloaded.manifest.featureSchemaVersion,
            createdAt: now,
            lastUpdatedAt: now,
            trainingSessions: 0,
            trainedTransitions: 0
        )
    }

    enum InstallError: LocalizedError {
        case manifestMetadataMismatch

        var errorDescription: String? {
            "Metadane pobranego modelu nie zgadzają się z manifestem."
        }
    }
}
