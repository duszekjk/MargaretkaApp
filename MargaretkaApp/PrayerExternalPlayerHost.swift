#if os(iOS)
import AVKit
import SwiftUI

struct PrayerExternalPlayerViewControllerHost: UIViewControllerRepresentable {
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
        print("[ExternalDisplay] AVPlayerViewController attached")
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== PrayerExternalDisplayController.shared.player {
            controller.player = PrayerExternalDisplayController.shared.player
        }
    }
}
#endif
