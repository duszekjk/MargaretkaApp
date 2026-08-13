import CryptoKit
import Foundation

struct PrayerAutoAdvanceDownloadedBase {
    let manifest: PrayerAutoAdvanceManifest
    let archiveData: Data
}

enum PrayerAutoAdvanceCoreMLDownloader {
    static let manifestURL = URL(string: "https://heptadaisy.duszekjk.com/api/models/prayer-auto-advance/latest/")!

    static func fetch() async throws -> PrayerAutoAdvanceDownloadedBase {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let (manifestData, manifestResponse) = try await URLSession.shared.data(from: manifestURL)
        try validate(manifestResponse)
        let manifest = try decoder.decode(PrayerAutoAdvanceManifest.self, from: manifestData)
        guard manifest.featureSchemaVersion == PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion else {
            throw DownloadError.incompatibleFeatureSchema
        }

        let (archiveData, archiveResponse) = try await URLSession.shared.data(from: manifest.modelURL)
        try validate(archiveResponse)
        if let expectedSize = manifest.size, archiveData.count != expectedSize {
            throw DownloadError.sizeMismatch
        }
        let digest = SHA256.hash(data: archiveData).map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.sha256.lowercased() else {
            throw DownloadError.checksumMismatch
        }
        return PrayerAutoAdvanceDownloadedBase(manifest: manifest, archiveData: archiveData)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DownloadError.invalidResponse
        }
    }

    enum DownloadError: LocalizedError {
        case invalidResponse
        case incompatibleFeatureSchema
        case sizeMismatch
        case checksumMismatch

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Serwer modelu zwrócił nieprawidłową odpowiedź."
            case .incompatibleFeatureSchema: "Model ma niezgodny schemat cech."
            case .sizeMismatch: "Pobrany model ma nieprawidłowy rozmiar."
            case .checksumMismatch: "Pobrany model ma nieprawidłową sumę kontrolną."
            }
        }
    }
}
