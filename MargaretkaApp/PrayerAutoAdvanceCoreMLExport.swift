import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func exportURL() throws -> URL {
        guard model != nil else {
            throw PrayerAutoAdvanceCoreMLExportError.modelUnavailable
        }
        let version = metadata?.baseModelVersion ?? 0
        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("PrayerAutoAdvance-v\(version)-personalized.aar")
        try PrayerAutoAdvanceArchive.createArchive(from: modelURL, to: destination)
        return destination
    }
}

enum PrayerAutoAdvanceCoreMLExportError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            "Brak lokalnego modelu do wyeksportowania."
        }
    }
}
