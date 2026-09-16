#if os(iOS)
import AVFoundation
import AVKit
import SwiftUI

struct PrayerExternalPlayerViewControllerHost: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = PrayerExternalDisplayController.shared.player
        controller.showsPlaybackControls = false
        controller.allowsPictureInPicturePlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.view.accessibilityElementsHidden = true
        context.coordinator.startKeepAlive()
        print("[ExternalDisplay] AVPlayerViewController attached")
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== PrayerExternalDisplayController.shared.player {
            controller.player = PrayerExternalDisplayController.shared.player
        }
        context.coordinator.startKeepAlive()
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.stopKeepAlive()
        controller.player = nil
    }

    @MainActor
    final class Coordinator {
        private var timeObserver: Any?
        private var isSeeking = false

        func startKeepAlive() {
            guard timeObserver == nil else { return }

            let player = PrayerExternalDisplayController.shared.player
            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main
            ) { [weak self, weak player] time in
                Task { @MainActor in
                    guard let self,
                          let player,
                          !self.isSeeking,
                          player.rate > 0,
                          let item = player.currentItem else { return }

                    let durationSeconds = CMTimeGetSeconds(item.duration)
                    let currentSeconds = CMTimeGetSeconds(time)
                    guard durationSeconds.isFinite,
                          durationSeconds > 4,
                          currentSeconds.isFinite else { return }

                    // The generated slide is currently a short static movie.
                    // AirPlay can treat reaching the end of that asset as the end
                    // of the external playback session even when AVPlayerLooper is
                    // present. Seek well before EOF so external playback remains
                    // continuously active while the visible frame stays unchanged.
                    let rewindAt = max(1, durationSeconds - 3)
                    guard currentSeconds >= rewindAt else { return }

                    self.isSeeking = true
                    player.seek(
                        to: .zero,
                        toleranceBefore: .zero,
                        toleranceAfter: .zero
                    ) { [weak self, weak player] _ in
                        Task { @MainActor in
                            self?.isSeeking = false
                            player?.play()
                        }
                    }
                }
            }
        }

        func stopKeepAlive() {
            guard let timeObserver else { return }
            PrayerExternalDisplayController.shared.player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
            isSeeking = false
        }

        deinit {
            if let timeObserver {
                PrayerExternalDisplayController.shared.player.removeTimeObserver(timeObserver)
            }
        }
    }
}
#endif
