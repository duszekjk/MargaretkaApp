import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func ensureModelAvailable() async -> Bool {
        if model != nil { return true }
        if isDownloading { return false }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let downloaded = try await PrayerAutoAdvanceCoreMLDownloader.fetch()
            try PrayerAutoAdvanceCoreMLInstall.run(downloaded, state: self)
            try PrayerAutoAdvanceCoreMLDiskState.save(self)
            lastError = nil
            return model != nil
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
