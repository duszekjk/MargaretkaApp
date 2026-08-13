import CryptoKit
import Foundation

extension PrayerAutoAdvanceStore {
    static let manifestURL = URL(string: "https://heptadaisy.duszekjk.com/api/models/prayer-auto-advance/latest/")!

    func ensureModelAvailable() async -> Bool {
        if model != nil { return true }
        return await downloadLatestBaseModel()
    }

    @discardableResult
    func downloadLatestBaseModel() async -> Bool {
        guard !isDownloading else { return false }
        setDownloadState(true)
        defer { if isDownloading { setDownloadState(false, error: lastError) } }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let (manifestData, manifestResponse) = try await URLSession.shared.data(from: Self.manifestURL)
            try validateResponse(manifestResponse)
            let manifest = try decoder.decode(PrayerAutoAdvanceManifest.self, from: manifestData)
            guard manifest.featureSchemaVersion == PrayerAutoAdvanceModelPayload.currentFeatureSchemaVersion else {
                throw DownloadError.incompatibleFeatureSchema
            }

            let (modelData, modelResponse) = try await URLSession.shared.data(from: manifest.modelURL)
            try validateResponse(modelResponse)
            guard checksum(modelData) == manifest.sha256.lowercased() else {
                throw DownloadError.checksumMismatch
            }

            var payload = try decoder.decode(PrayerAutoAdvanceModelPayload.self, from: modelData)
            guard payload.isStructurallyValid,
                  payload.modelVersion == manifest.modelVersion,
                  payload.featureSchemaVersion == manifest.featureSchemaVersion else {
                throw DownloadError.invalidModel
            }
            payload.trainedTransitions = 0
            payload.trainingSteps = 0
            try replaceWithDownloadedBase(payload)
            setDownloadState(false)
            return true
        } catch {
            setDownloadState(false, error: error.localizedDescription)
            return false
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw DownloadError.invalidServerResponse
        }
    }

    private func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    enum DownloadError: LocalizedError {
        case invalidServerResponse
        case checksumMismatch
        case incompatibleFeatureSchema
        case invalidModel

        var errorDescription: String? {
            switch self {
            case .invalidServerResponse: "Serwer modelu zwrócił nieprawidłową odpowiedź."
            case .checksumMismatch: "Pobrany model ma nieprawidłową sumę kontrolną."
            case .incompatibleFeatureSchema: "Model jest przeznaczony dla innej wersji mechanizmu automatycznego przełączania."
            case .invalidModel: "Pobrany model automatycznego przełączania jest nieprawidłowy."
            }
        }
    }
}
