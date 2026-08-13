import Foundation
internal import Combine

@MainActor
final class PrayerAutoAdvanceStore: ObservableObject {
    static let shared = PrayerAutoAdvanceStore()

    @Published private(set) var model: PrayerAutoAdvanceModelPayload?
    @Published private(set) var metadata: PrayerAutoAdvanceLocalMetadata?
    @Published private(set) var isDownloading = false
    @Published private(set) var lastError: String?

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        loadLocalModel()
    }

    var hasModel: Bool { model != nil }

    var storageDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrayerAutoAdvance", isDirectory: true)
    }

    var modelURL: URL { storageDirectory.appendingPathComponent("model.json") }
    var metadataURL: URL { storageDirectory.appendingPathComponent("metadata.json") }

#if DEBUG
    func createDeveloperSeed() throws {
        let payload = PrayerAutoAdvanceModelPayload.developerSeed()
        let now = Date()
        let localMetadata = PrayerAutoAdvanceLocalMetadata(
            baseModelVersion: payload.modelVersion,
            featureSchemaVersion: payload.featureSchemaVersion,
            createdAt: now,
            lastUpdatedAt: now,
            trainingSessions: 0,
            trainedTransitions: 0
        )
        try persist(payload, metadata: localMetadata)
        model = payload
        metadata = localMetadata
        lastError = nil
    }
#endif

    func updateModel(_ updated: PrayerAutoAdvanceModelPayload, countedSession: Bool = false) throws {
        guard updated.isStructurallyValid else { throw StoreError.invalidModel }
        var localMetadata = metadata ?? PrayerAutoAdvanceLocalMetadata(
            baseModelVersion: updated.modelVersion,
            featureSchemaVersion: updated.featureSchemaVersion,
            createdAt: Date(),
            lastUpdatedAt: Date(),
            trainingSessions: 0,
            trainedTransitions: updated.trainedTransitions
        )
        localMetadata.lastUpdatedAt = Date()
        localMetadata.trainedTransitions = updated.trainedTransitions
        if countedSession { localMetadata.trainingSessions += 1 }
        try persist(updated, metadata: localMetadata)
        model = updated
        metadata = localMetadata
    }

    func exportURL() throws -> URL {
        guard let model else { throw StoreError.modelUnavailable }
        let url = fileManager.temporaryDirectory.appendingPathComponent(
            "PrayerAutoAdvance-v\(model.modelVersion)-trained.json"
        )
        try encoder.encode(model).write(to: url, options: .atomic)
        return url
    }

    func replaceWithDownloadedBase(_ payload: PrayerAutoAdvanceModelPayload) throws {
        guard payload.isStructurallyValid else { throw StoreError.invalidModel }
        let now = Date()
        let localMetadata = PrayerAutoAdvanceLocalMetadata(
            baseModelVersion: payload.modelVersion,
            featureSchemaVersion: payload.featureSchemaVersion,
            createdAt: now,
            lastUpdatedAt: now,
            trainingSessions: 0,
            trainedTransitions: 0
        )
        try persist(payload, metadata: localMetadata)
        model = payload
        metadata = localMetadata
        lastError = nil
    }

    func setDownloadState(_ active: Bool, error: String? = nil) {
        isDownloading = active
        lastError = error
    }

    func clearLoadedState() {
        model = nil
        metadata = nil
        lastError = nil
    }

    private func loadLocalModel() {
        do {
            guard fileManager.fileExists(atPath: modelURL.path) else { return }
            let payload = try decoder.decode(PrayerAutoAdvanceModelPayload.self, from: Data(contentsOf: modelURL))
            guard payload.isStructurallyValid else { throw StoreError.invalidModel }
            model = payload
            if fileManager.fileExists(atPath: metadataURL.path) {
                metadata = try decoder.decode(PrayerAutoAdvanceLocalMetadata.self, from: Data(contentsOf: metadataURL))
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func persist(_ payload: PrayerAutoAdvanceModelPayload, metadata: PrayerAutoAdvanceLocalMetadata) throws {
        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        try encoder.encode(payload).write(to: modelURL, options: .atomic)
        try encoder.encode(metadata).write(to: metadataURL, options: .atomic)
    }

    enum StoreError: LocalizedError {
        case invalidModel
        case modelUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidModel: "Model automatycznego przełączania jest nieprawidłowy."
            case .modelUnavailable: "Brak lokalnego modelu automatycznego przełączania."
            }
        }
    }
}

enum PrayerAutoAdvancePreferences {
    static let trainingEnabledKey = "prayerAutoAdvance.trainingEnabled"
    static let automaticEnabledKey = "prayerAutoAdvance.automaticEnabled"
}
