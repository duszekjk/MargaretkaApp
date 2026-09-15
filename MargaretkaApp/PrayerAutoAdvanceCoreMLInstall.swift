import Foundation

enum PrayerAutoAdvanceCoreMLInstall {
    @MainActor
    static func run(
        _ downloaded: PrayerAutoAdvanceDownloadedBase,
        state: PrayerAutoAdvanceCoreMLState
    ) throws {
        try state.fileManager.createDirectory(at: state.directory, withIntermediateDirectories: true)
        let archive = state.fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("aar")
        let staging = state.directory.appendingPathComponent("Incoming-\(UUID().uuidString).mlmodelc", isDirectory: true)
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

        if state.fileManager.fileExists(atPath: state.modelURL.path) {
            _ = try state.fileManager.replaceItemAt(state.modelURL, withItemAt: staging)
        } else {
            try state.fileManager.moveItem(at: staging, to: state.modelURL)
        }
        state.model = try PrayerAutoAdvanceCoreMLModel(compiledURL: state.modelURL)

        let now = Date()
        state.metadata = PrayerAutoAdvanceLocalMetadata(
            baseModelVersion: downloaded.manifest.modelVersion,
            featureSchemaVersion: downloaded.manifest.featureSchemaVersion,
            createdAt: now,
            lastUpdatedAt: now,
            trainingSessions: 0,
            trainedTransitions: 0,
            serverPublishedAt: downloaded.manifest.publishedAt,
            serverSHA256: downloaded.manifest.sha256.lowercased()
        )
    }

    enum InstallError: LocalizedError {
        case manifestMetadataMismatch

        var errorDescription: String? {
            "Metadane pobranego modelu nie zgadzają się z manifestem."
        }
    }
}
