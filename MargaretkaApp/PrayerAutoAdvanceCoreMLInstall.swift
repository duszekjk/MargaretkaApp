import Foundation

enum PrayerAutoAdvanceCoreMLInstall {
    @MainActor
    static func run(
        _ downloaded: PrayerAutoAdvanceDownloadedBase,
        state: PrayerAutoAdvanceCoreMLState
    ) throws {
        try state.fileManager.createDirectory(at: state.directory, withIntermediateDirectories: true)

        let archive = state.fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aar")
        let staging = state.directory
            .appendingPathComponent("Incoming-\(UUID().uuidString).mlmodelc", isDirectory: true)
        let backupName = "Previous-\(UUID().uuidString).mlmodelc"
        let backup = state.directory.appendingPathComponent(backupName, isDirectory: true)

        defer {
            try? state.fileManager.removeItem(at: archive)
            try? state.fileManager.removeItem(at: staging)
            try? state.fileManager.removeItem(at: backup)
        }

        try downloaded.archiveData.write(to: archive, options: .atomic)
        try PrayerAutoAdvanceArchive.extractArchive(at: archive, to: staging)

        let stagedModel = try PrayerAutoAdvanceCoreMLModel(compiledURL: staging)
        guard stagedModel.declaredModelVersion == downloaded.manifest.modelVersion,
              stagedModel.declaredFeatureSchemaVersion == downloaded.manifest.featureSchemaVersion else {
            throw InstallError.manifestMetadataMismatch
        }

        let previousModel = state.model
        let previousMetadata = state.metadata
        let previousMetadataData = try? Data(contentsOf: state.metadataURL)
        let hadExistingModel = state.fileManager.fileExists(atPath: state.modelURL.path)
        var activatedCandidate = false

        do {
            if hadExistingModel {
                _ = try state.fileManager.replaceItemAt(
                    state.modelURL,
                    withItemAt: staging,
                    backupItemName: backupName,
                    options: [.withoutDeletingBackupItem]
                )
            } else {
                try state.fileManager.moveItem(at: staging, to: state.modelURL)
            }
            activatedCandidate = true

            state.model = try PrayerAutoAdvanceCoreMLModel(compiledURL: state.modelURL)

            let now = Date()
            state.metadata = PrayerAutoAdvanceLocalMetadata(
                baseModelVersion: downloaded.manifest.modelVersion,
                featureSchemaVersion: downloaded.manifest.featureSchemaVersion,
                createdAt: now,
                lastUpdatedAt: now,
                trainingSessions: 0,
                trainedTransitions: 0,
                serverPublishedAt: downloaded.manifest.publishedAt
            )

            // Persist metadata before discarding the backup. A thrown persistence error
            // rolls both the model and its metadata back to the previous working pair.
            try PrayerAutoAdvanceCoreMLDiskState.save(state)
        } catch {
            state.model = previousModel
            state.metadata = previousMetadata

            if activatedCandidate {
                try? state.fileManager.removeItem(at: state.modelURL)
                if hadExistingModel, state.fileManager.fileExists(atPath: backup.path) {
                    do {
                        try state.fileManager.moveItem(at: backup, to: state.modelURL)
                        state.model = (try? PrayerAutoAdvanceCoreMLModel(compiledURL: state.modelURL)) ?? previousModel
                    } catch {
                        // Keep the already loaded previous in-memory model if filesystem
                        // rollback itself fails; report the original install failure below.
                        state.model = previousModel
                    }
                }
            }

            if let previousMetadataData {
                try? previousMetadataData.write(to: state.metadataURL, options: .atomic)
            } else {
                try? state.fileManager.removeItem(at: state.metadataURL)
            }
            throw error
        }
    }

    enum InstallError: LocalizedError {
        case manifestMetadataMismatch

        var errorDescription: String? {
            "Metadane pobranego modelu nie zgadzają się z manifestem."
        }
    }
}
