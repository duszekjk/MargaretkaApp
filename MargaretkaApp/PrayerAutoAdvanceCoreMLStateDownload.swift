import Foundation

extension PrayerAutoAdvanceCoreMLState {
    func ensureModelAvailable() async -> Bool {
#if DEBUG
        if model == nil {
            do {
                try installBundledDeveloperSeed()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
        return await refreshLatestModelFromServerIfNeeded()
#else
        if model != nil { return true }
        if isDownloading {
            while isDownloading, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
            }
            return model != nil
        }

        isDownloading = true
        defer { isDownloading = false }
        do {
            let downloaded = try await PrayerAutoAdvanceCoreMLDownloader.fetch(slot: .best)
            try PrayerAutoAdvanceCoreMLInstall.run(downloaded, state: self)
            try PrayerAutoAdvanceCoreMLDiskState.save(self)
            lastError = nil
            return model != nil
        } catch {
            lastError = error.localizedDescription
            return false
        }
#endif
    }

#if DEBUG
    @discardableResult
    func refreshLatestModelFromServerIfNeeded() async -> Bool {
        if model == nil {
            do {
                try installBundledDeveloperSeed()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }

        if isDownloading {
            while isDownloading, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
            }
            return model != nil
        }

        isDownloading = true
        defer { isDownloading = false }

        do {
            let manifest = try await PrayerAutoAdvanceCoreMLDownloader.fetchManifest(slot: .latest)
            if let remotePublishedAt = manifest.publishedAt,
               let localPublishedAt = metadata?.serverPublishedAt,
               remotePublishedAt <= localPublishedAt {
                lastError = nil
                return model != nil
            }

            let downloaded = try await PrayerAutoAdvanceCoreMLDownloader.fetch(slot: .latest, manifest: manifest)
            try PrayerAutoAdvanceCoreMLInstall.run(downloaded, state: self)
            try PrayerAutoAdvanceCoreMLDiskState.save(self)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            PrayerAutoAdvanceTrainingDiagnostics.shared.event(
                "debug model refresh skipped: \(error.localizedDescription)"
            )
            return model != nil
        }
    }
#endif
}
