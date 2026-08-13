import AppleArchive
import Foundation
import System

enum PrayerAutoAdvanceArchive {
    static func createArchive(from directoryURL: URL, to archiveURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
        guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM") else {
            throw ArchiveError.cannotCreateKeySet
        }

        try ArchiveByteStream.withFileStream(
            path: FilePath(archiveURL.path),
            mode: .writeOnly,
            options: [.create, .truncate],
            permissions: FilePermissions(rawValue: 0o644)
        ) { fileStream in
            try ArchiveByteStream.withCompressionStream(using: .lzfse, writingTo: fileStream) { compressedStream in
                try ArchiveStream.withEncodeStream(writingTo: compressedStream) { encodeStream in
                    try encodeStream.writeDirectoryContents(
                        archiveFrom: FilePath(directoryURL.path),
                        keySet: keySet
                    )
                }
            }
        }
    }

    static func extractArchive(at archiveURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        try ArchiveByteStream.withFileStream(
            path: FilePath(archiveURL.path),
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o644)
        ) { fileStream in
            try ArchiveByteStream.withDecompressionStream(readingFrom: fileStream) { decompressedStream in
                try ArchiveStream.withDecodeStream(readingFrom: decompressedStream) { decodeStream in
                    try ArchiveStream.withExtractStream(extractingTo: FilePath(destinationURL.path)) { extractStream in
                        _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
                    }
                }
            }
        }
    }

    enum ArchiveError: LocalizedError {
        case cannotCreateKeySet

        var errorDescription: String? {
            switch self {
            case .cannotCreateKeySet:
                "Nie udało się przygotować archiwum modelu automatycznego przełączania."
            }
        }
    }
}
