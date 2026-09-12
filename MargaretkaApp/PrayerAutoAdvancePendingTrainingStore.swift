import Foundation

struct PrayerAutoAdvancePendingTrainingPage: Codable, Sendable, Identifiable {
    let id: UUID
    let pageID: String
    let createdAt: Date
    let samples: [PrayerAutoAdvanceLabeledSample]
}

struct PrayerAutoAdvancePendingTrainingSnapshot: Sendable {
    let pages: [PrayerAutoAdvancePendingTrainingPage]

    var pageCount: Int { pages.count }
    var samples: [PrayerAutoAdvanceLabeledSample] { pages.flatMap(\.samples) }
    var pageIDs: Set<UUID> { Set(pages.map(\.id)) }
}

/// Durable, schema-local storage for materialized training pages. Each page is a
/// separate binary property list, so adding one page never rewrites the previous
/// V12 feature vectors. Files are removed only after the personalized model has
/// been written successfully.
enum PrayerAutoAdvancePendingTrainingStore {
    /// Temporary test value. Change this single constant to 100 for production.
    static let minimumPageCountForUpdate = 20

    private static let fileExtension = "trainingpage"

    static func pageCount(in directory: URL, fileManager: FileManager = .default) -> Int {
        pageURLs(in: directory, fileManager: fileManager).count
    }

    static func append(
        pageID: String,
        batch: PrayerAutoAdvanceLabeledBatch,
        createdAt: Date,
        to directory: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let page = PrayerAutoAdvancePendingTrainingPage(
            id: UUID(),
            pageID: pageID,
            createdAt: createdAt,
            samples: batch.samples
        )
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(page)
        let url = directory
            .appendingPathComponent(page.id.uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
    }

    static func loadSnapshot(
        from directory: URL,
        fileManager: FileManager = .default
    ) throws -> PrayerAutoAdvancePendingTrainingSnapshot {
        let decoder = PropertyListDecoder()
        let pages = try pageURLs(in: directory, fileManager: fileManager).map { url in
            try decoder.decode(
                PrayerAutoAdvancePendingTrainingPage.self,
                from: Data(contentsOf: url, options: .mappedIfSafe)
            )
        }
        return PrayerAutoAdvancePendingTrainingSnapshot(
            pages: pages.sorted { $0.createdAt < $1.createdAt }
        )
    }

    static func remove(
        pageIDs: Set<UUID>,
        from directory: URL,
        fileManager: FileManager = .default
    ) throws {
        guard !pageIDs.isEmpty else { return }
        for id in pageIDs {
            let url = directory
                .appendingPathComponent(id.uuidString)
                .appendingPathExtension(fileExtension)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private static func pageURLs(
        in directory: URL,
        fileManager: FileManager
    ) -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls
            .filter { $0.pathExtension == fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
