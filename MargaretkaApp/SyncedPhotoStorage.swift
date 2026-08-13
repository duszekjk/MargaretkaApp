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

    func removeOriginal(for assetID: UUID) {
        try? fileManager.removeItem(at: url(for: assetID))
    }

    func removeOrphanedOriginals(referencedBy assetIDs: Set<UUID>) {
        for assetID in allStoredAssetIDs() where !assetIDs.contains(assetID) {
            removeOriginal(for: assetID)
        }
    }

    func fingerprint(for assetID: UUID) -> String? {
        let fileURL = url(for: assetID)
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return "\(size.int64Value):\(modified.timeIntervalSince1970)"
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
