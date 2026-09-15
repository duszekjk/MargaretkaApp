#if DEBUG
import CryptoKit
import Foundation
import Security

enum PrayerAutoAdvanceCoreMLUploader {
    static let uploadURL = URL(string: "https://heptadaisy.duszekjk.com/api/models/prayer-auto-advance/upload/")!

    static func upload(modelAt modelURL: URL, trainingLoss: Double) async throws -> Date? {
        guard trainingLoss.isFinite, trainingLoss >= 0 else {
            throw UploadError.invalidTrainingLoss
        }
        guard let accessToken = accessToken() else {
            throw UploadError.signedOut
        }

        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aar")
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        try PrayerAutoAdvanceArchive.createArchive(from: modelURL, to: archiveURL)
        let data = try Data(contentsOf: archiveURL)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(String(PrayerAutoAdvanceCoreMLModel.currentModelVersion), forHTTPHeaderField: "X-Model-Version")
        request.setValue(String(PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion), forHTTPHeaderField: "X-Feature-Schema-Version")
        request.setValue(String(format: "%.12f", trainingLoss), forHTTPHeaderField: "X-Training-Loss")
        request.setValue(digest, forHTTPHeaderField: "X-SHA256")

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ServerError.self, from: responseData).detail)
            throw UploadError.server(status: http.statusCode, detail: detail)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UploadResponse.self, from: responseData).latest.publishedAt
    }

    private static func accessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.duszekjk.MargaretkaApp.sync",
            kSecAttrAccount as String: "accessToken",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private struct UploadResponse: Decodable {
        let latest: Latest

        struct Latest: Decodable {
            let publishedAt: Date?
        }
    }

    private struct ServerError: Decodable {
        let detail: String
    }

    enum UploadError: LocalizedError {
        case invalidTrainingLoss
        case signedOut
        case invalidResponse
        case server(status: Int, detail: String?)

        var errorDescription: String? {
            switch self {
            case .invalidTrainingLoss:
                "Nie można wysłać modelu bez poprawnej wartości loss."
            case .signedOut:
                "Nie wysłano modelu treningowego: zaloguj się przez Apple, aby uwierzytelnić upload."
            case .invalidResponse:
                "Serwer modelu zwrócił nieprawidłową odpowiedź podczas uploadu."
            case let .server(status, detail):
                detail ?? "Upload modelu nie powiódł się (HTTP \(status))."
            }
        }
    }
}
#endif
