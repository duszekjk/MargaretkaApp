#if os(iOS)
import AVFoundation
import AVKit
internal import Combine
import SwiftUI

extension Notification.Name {
    static let prayerAudioAutoAdvanceDidFinish = Notification.Name(
        "margaretka.prayerAudioAutoAdvance.didFinish"
    )
    static let prayerAudioAutoAdvanceModeChanged = Notification.Name(
        "margaretka.prayerAudioAutoAdvance.modeChanged"
    )
}

@MainActor
final class PrayerAudioAutoAdvanceCoordinator: ObservableObject {
    static let shared = PrayerAudioAutoAdvanceCoordinator()

    @Published private(set) var isEnabled = false

    private var pageObserver: NSObjectProtocol?
    private var finishObserver: NSObjectProtocol?

    private init() {
        pageObserver = NotificationCenter.default.addObserver(
            forName: PrayerExternalDisplayStore.pageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await Task.yield()
                self?.handlePageChange()
            }
        }

        finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      self.isEnabled,
                      let finishedItem = notification.object as? AVPlayerItem,
                      finishedItem === PrayerExternalDisplayController.shared.audioPlayer.currentItem else {
                    return
                }

                NotificationCenter.default.post(
                    name: .prayerAudioAutoAdvanceDidFinish,
                    object: nil
                )
            }
        }
    }

    func toggle() {
        if isEnabled {
            stop()
            return
        }

        let controller = PrayerExternalDisplayController.shared
        guard controller.hasCurrentPageAudio else { return }

        isEnabled = true
        NotificationCenter.default.post(
            name: .prayerAudioAutoAdvanceModeChanged,
            object: nil
        )

        if controller.isAudioMuted {
            controller.toggleAudioMute()
        }
    }

    func stop() {
        guard isEnabled else { return }

        isEnabled = false
        let controller = PrayerExternalDisplayController.shared
        if controller.hasCurrentPageAudio && !controller.isAudioMuted {
            controller.toggleAudioMute()
        }

        NotificationCenter.default.post(
            name: .prayerAudioAutoAdvanceModeChanged,
            object: nil
        )
    }

    private func handlePageChange() {
        guard isEnabled else { return }

        let controller = PrayerExternalDisplayController.shared
        guard controller.hasCurrentPageAudio else {
            stop()
            return
        }

        if controller.isAudioMuted {
            controller.toggleAudioMute()
        }
    }
}

@MainActor
final class PrayerAirPlayRouteAvailability: ObservableObject {
    static let shared = PrayerAirPlayRouteAvailability()

    @Published private(set) var hasAlternativeRoute = false

    private let detector = AVRouteDetector()
    private var observer: NSObjectProtocol?

    private init() {
        detector.isRouteDetectionEnabled = true
        hasAlternativeRoute = detector.multipleRoutesDetected
        observer = NotificationCenter.default.addObserver(
            forName: .AVRouteDetectorMultipleRoutesDetectedDidChange,
            object: detector,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.hasAlternativeRoute = self.detector.multipleRoutesDetected
            }
        }
    }
}

struct PrayerExternalPlaybackControls: View {
    @StateObject private var routes = PrayerAirPlayRouteAvailability.shared
    @ObservedObject private var controller = PrayerExternalDisplayController.shared
    @ObservedObject private var audioAutoAdvance = PrayerAudioAutoAdvanceCoordinator.shared

    var body: some View {
        HStack(spacing: 12) {
            if controller.hasCurrentPageAudio {
                Button {
                    audioAutoAdvance.toggle()
                } label: {
                    Image(systemName: audioAutoAdvance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .imageScale(.medium)
                }
                .accessibilityLabel(
                    audioAutoAdvance.isEnabled
                        ? "Wyłącz automatyczne audio modlitwy"
                        : "Włącz automatyczne audio modlitwy"
                )
            }

            if routes.hasAlternativeRoute || controller.player.isExternalPlaybackActive {
                PrayerAirPlayRoutePicker()
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("AirPlay")
            }
        }
    }
}

private struct PrayerAirPlayRoutePicker: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.delegate = context.coordinator
        picker.prioritizesVideoDevices = true
        picker.backgroundColor = .clear
        picker.tintColor = .label
        picker.activeTintColor = .systemBlue
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {}

    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            Task { @MainActor in
                // Prime the external video item first, then leave the global audio
                // session in the exact same configuration used by speech capture.
                // Entering the first prayer must not switch the session category
                // from .playback to .playAndRecord while AirPlay is active.
                PrayerExternalDisplayController.shared.prepareForAirPlay()

                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(
                        .playAndRecord,
                        mode: .measurement,
                        options: [.duckOthers, .allowAirPlay]
                    )
                    try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
                    try session.setActive(true)
                    print(
                        "[ExternalDisplay] AirPlay route picker session stabilized " +
                        "category=\(session.category.rawValue) mode=\(session.mode.rawValue)"
                    )
                } catch {
                    print("[ExternalDisplay] stable AirPlay audio session setup failed: \(error)")
                }
            }
        }
    }
}
#endif
