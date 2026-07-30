import Foundation
internal import UniformTypeIdentifiers

enum AudioStorage {
    static func removeAllStoredAudioFiles() {
        guard let directory = try? applicationSupportDirectory(create: false),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        for file in files {
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let type = UTType(filenameExtension: file.pathExtension),
                  type.conforms(to: .audio) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func removeOrphanedFiles(referencedBy prayers: [Prayer]) {
        let referencedNames = Set(prayers.compactMap(\.audioFilename).filter { !$0.isEmpty })
        guard let directory = try? applicationSupportDirectory(create: false),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        for file in files {
            guard referencedNames.contains(file.lastPathComponent) == false,
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let type = UTType(filenameExtension: file.pathExtension),
                  type.conforms(to: .audio) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func removeFile(named filename: String?) {
        guard let filename, !filename.isEmpty,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              let directory = try? applicationSupportDirectory(create: false) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }

    static func applicationSupportDirectory(create: Bool) throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
    }
}
