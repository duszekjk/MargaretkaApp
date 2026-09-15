import CryptoKit
import Foundation

struct PrayerAutoAdvanceDownloadedBase {
    let manifest: PrayerAutoAdvanceManifest
    let archiveData: Data
}

enum PrayerAutoAdvanceCoreMLDownloader {
    enum Slot: String, Sendable {
        case latest
        case best
    }

    static let baseURL = URL(string: "https://heptadaisy.duszekjk.com/api/models/prayer-auto-advance/")!

    static func manifestURL(for slot: Slot) -> URL {
        baseURL.appendingPathComponent(slot.rawValue).appendingPathComponent("")
    }

    static func fetchManifest(slot: Slot) async throws -> PrayerAutoAdvanceManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = manifestURL(for: slot)
        let (manifestData, manifestResponse) = try await URLSession.shared.data(from: url)
        try validate(manifestResponse)
        let manifest = try decoder.decode(PrayerAutoAdvanceManifest.self, from: manifestData)
        try validateManifest(manifest, manifestURL: url)
        return manifest
    }

    static func fetch(slot: Slot, manifest suppliedManifest: PrayerAutoAdvanceManifest? = nil) async throws -> PrayerAutoAdvanceDownloadedBase {
        let manifest: PrayerAutoAdvanceManifest
        if let suppliedManifest {
            manifest = suppliedManifest
        } else {
            manifest = try await fetchManifest(slot: slot)
        }
        let manifestURL = manifestURL(for: slot)
        try validateManifest(manifest, manifestURL: manifestURL)

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

    private static func validateManifest(_ manifest: PrayerAutoAdvanceManifest, manifestURL: URL) throws {
        guard manifest.modelVersion == PrayerAutoAdvanceCoreMLModel.currentModelVersion else {
            throw DownloadError.incompatibleModelVersion
        }
        guard manifest.featureSchemaVersion == PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion else {
            throw DownloadError.incompatibleFeatureSchema
        }
        guard manifest.modelURL.scheme?.lowercased() == "https",
              manifest.modelURL.host?.lowercased() == manifestURL.host?.lowercased() else {
            throw DownloadError.invalidModelURL
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DownloadError.invalidResponse
        }
    }

    enum DownloadError: LocalizedError {
        case invalidResponse
        case incompatibleFeatureSchema
        case incompatibleModelVersion
        case invalidModelURL
        case sizeMismatch
        case checksumMismatch

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Serwer modelu zwrócił nieprawidłową odpowiedź."
            case .incompatibleFeatureSchema: "Model ma niezgodny schemat cech."
            case .incompatibleModelVersion: "Serwer udostępnia niezgodną wersję modelu."
            case .invalidModelURL: "Serwer wskazał niedozwolony adres modelu."
            case .sizeMismatch: "Pobrany model ma nieprawidłowy rozmiar."
            case .checksumMismatch: "Pobrany model ma nieprawidłową sumę kontrolną."
            }
        }
    }
}
