import Foundation

enum PhotoLayoutFamily: String, Codable, CaseIterable {
    case iPhone
    case iPad
}

struct PhotoPlacement: Codable, Hashable {
    var scale: Double
    var offsetX: Double
    var offsetY: Double

    static let centered = PhotoPlacement(scale: 1, offsetX: 0, offsetY: 0)
}

extension Notification.Name {
    static let syncPhotoQueued = Notification.Name("syncPhotoQueued")
}

/// Keeps the exact bytes selected by the user. `Priest.photoData` remains a
/// deliberately small rendering preview; this file is the source uploaded to
/// the sync service and later used to derive device-specific renditions.
final class SyncedPhotoStorage: @unchecked Sendable {
    static let shared = SyncedPhotoStorage()

    private let fileManager = FileManager.default

    private init() {}

    var directory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let result = base.appendingPathComponent("SyncedOriginalPhotos", isDirectory: true)
        try? fileManager.createDirectory(
            at: result,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        return result
    }

    func url(for assetID: UUID) -> URL {
        directory.appendingPathComponent(assetID.uuidString.lowercased()).appendingPathExtension("original")
    }

    func saveOriginal(_ data: Data, assetID: UUID) throws {
        try data.write(
            to: url(for: assetID),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        NotificationCenter.default.post(name: .syncPhotoQueued, object: assetID)
    }

    func data(for assetID: UUID) throws -> Data {
        try Data(contentsOf: url(for: assetID))
    }

    func contains(_ assetID: UUID) -> Bool {
        fileManager.fileExists(atPath: url(for: assetID).path)
    }

    func allStoredAssetIDs() -> [UUID] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return files.compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) }
    }
}
