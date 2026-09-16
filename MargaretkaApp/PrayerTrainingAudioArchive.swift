import AVFoundation
import Foundation

struct PrayerTrainingAudioSuggestion: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    let duration: TimeInterval

    var id: String { url.path }
}

enum PrayerTrainingAudioArchive {
    static let maxRecordingsPerPage = 20
    private static let directoryName = "PrayerTrainingAudio"

    static func store(pageID: String, audio: PrayerAutoAdvanceAudioWindow) {
        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.archiveTrainingAudioKey),
              !audio.samples.isEmpty,
              audio.sampleRate > 0,
              let location = location(for: pageID, create: true) else { return }

        do {
            try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
            let url = location.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).caf")
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: audio.sampleRate,
                channels: 1,
                interleaved: false
            ),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(audio.samples.count)
            ),
            let channel = buffer.floatChannelData?[0] else { return }

            buffer.frameLength = AVAudioFrameCount(audio.samples.count)
            audio.samples.withUnsafeBufferPointer { source in
                guard let base = source.baseAddress else { return }
                channel.update(from: base, count: source.count)
            }

            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            prune(directory: location)
        } catch {
            print("PrayerTrainingAudioArchive store error: \(error.localizedDescription)")
        }
    }

    static func suggestions(for prayerID: UUID) -> [PrayerTrainingAudioSuggestion] {
        guard let prayerDirectory = try? rootDirectory(create: false)
            .appendingPathComponent(prayerID.uuidString.lowercased(), isDirectory: true),
              let pageDirectories = try? FileManager.default.contentsOfDirectory(
                at: prayerDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return pageDirectories
            .flatMap(suggestions(in:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func suggestion(forPageID pageID: String, closestTo date: Date) -> PrayerTrainingAudioSuggestion? {
        guard let directory = location(for: pageID, create: false) else { return nil }
        return suggestions(in: directory).min {
            abs($0.createdAt.timeIntervalSince(date)) < abs($1.createdAt.timeIntervalSince(date))
        }
    }

    static func adopt(_ suggestion: PrayerTrainingAudioSuggestion) throws -> String {
        let support = try AudioStorage.applicationSupportDirectory(create: true)
        let destination = support.appendingPathComponent("\(UUID().uuidString).caf")
        try FileManager.default.copyItem(at: suggestion.url, to: destination)
        return destination.lastPathComponent
    }

    static func removeAll() {
        guard let root = try? rootDirectory(create: false) else { return }
        try? FileManager.default.removeItem(at: root)
    }

    static func totalSize() -> Int64 {
        guard let root = try? rootDirectory(create: false),
              let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else { return 0 }
        var result: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            result += Int64(values.fileSize ?? 0)
        }
        return result
    }

    private static func suggestions(in directory: URL) -> [PrayerTrainingAudioSuggestion] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return files.compactMap { url in
            guard url.pathExtension.lowercased() == "caf" else { return nil }
            let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
                ?? creationDate(from: url)
                ?? .distantPast
            let duration = (try? AVAudioFile(forReading: url)).map {
                guard $0.fileFormat.sampleRate > 0 else { return 0 }
                return Double($0.length) / $0.fileFormat.sampleRate
            } ?? 0
            return PrayerTrainingAudioSuggestion(url: url, createdAt: createdAt, duration: duration)
        }
    }

    private static func location(for pageID: String, create: Bool) -> URL? {
        let components = pageID.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count >= 4,
              let prayerID = UUID(uuidString: String(components[2])),
              let root = try? rootDirectory(create: create) else { return nil }

        let pageKey = sanitized(String(components[3]))
        let location = root
            .appendingPathComponent(prayerID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(pageKey, isDirectory: true)

        if !create {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: location.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { return nil }
        }
        return location
    }

    private static func rootDirectory(create: Bool) throws -> URL {
        let support = try AudioStorage.applicationSupportDirectory(create: create)
        let root = support.appendingPathComponent(directoryName, isDirectory: true)
        if create {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        return String(scalars)
    }

    private static func prune(directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let ordered = files.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? creationDate(from: $0) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? creationDate(from: $1) ?? .distantPast
            return lhs > rhs
        }
        for url in ordered.dropFirst(maxRecordingsPerPage) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func creationDate(from url: URL) -> Date? {
        let prefix = url.deletingPathExtension().lastPathComponent.split(separator: "-").first
        guard let prefix, let interval = TimeInterval(String(prefix)) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
