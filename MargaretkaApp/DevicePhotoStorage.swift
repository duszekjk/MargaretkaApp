//
//  DevicePhotoStorage.swift
//  MargaretkaApp
//

import Foundation

/// Persistent, device-only copies of synchronized photo variants.
///
/// These files deliberately live outside `Priest`'s Codable representation:
/// they must survive an app restart, but must never be included in a backup or
/// sent back to the server as a source photo.
final class DevicePhotoStorage: @unchecked Sendable {
    static let shared = DevicePhotoStorage()

    private let fileManager = FileManager.default

    private init() {}

    var directory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("DevicePhotoVariants", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        return directory
    }

    func url(for assetID: UUID) -> URL {
        directory.appendingPathComponent(assetID.uuidString.lowercased()).appendingPathExtension("jpg")
    }

    func save(_ data: Data, for assetID: UUID) throws {
        try data.write(
            to: url(for: assetID),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func data(for assetID: UUID) -> Data? {
        try? Data(contentsOf: url(for: assetID), options: [.mappedIfSafe])
    }

    func contains(_ assetID: UUID) -> Bool {
        fileManager.fileExists(atPath: url(for: assetID).path)
    }

    func remove(for assetID: UUID) {
        try? fileManager.removeItem(at: url(for: assetID))
    }

    func removeOrphanedVariants(referencedBy assetIDs: Set<UUID>) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files {
            guard let assetID = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                  !assetIDs.contains(assetID) else { continue }
            try? fileManager.removeItem(at: file)
        }
    }
}
