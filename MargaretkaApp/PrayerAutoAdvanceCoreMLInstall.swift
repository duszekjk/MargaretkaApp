import Foundation

enum PrayerAutoAdvanceCoreMLInstall {
    @MainActor
    static func run(
        _ downloaded: PrayerAutoAdvanceDownloadedBase,
        state: PrayerAutoAdvanceCoreMLState
    ) throws {
        guard !state.fileManager.fileExists(atPath: state.modelURL.path) else {
            state.model = try PrayerAutoAdvanceCoreMLModel(compiledURL: state.modelURL)
            return
        }

        try state.fileManager.createDirectory(at: state.directory, withIntermediateDirectories: true)
        let archive = state.fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("aar")
        let staging = state.directory.appendingPathComponent("Incoming.mlmodelc", isDirectory: true)
        defer { try? state.fileManager.removeItem(at: archive) }

        try downloaded.archiveData.write(to: archive, options: .atomic)
        try PrayerAutoAdvanceArchive.extractArchive(at: archive, to: staging)
        _ = try PrayerAutoAdvanceCoreMLModel(compiledURL: staging)
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
}
