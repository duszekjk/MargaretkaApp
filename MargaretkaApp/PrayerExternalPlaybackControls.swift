#if os(iOS)
import AVFoundation
import AVKit
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
        if controller.hasCurrentPageAudio || routes.hasAlternativeRoute || controller.player.isExternalPlaybackActive {
            HStack(spacing: 8) {
                if controller.hasCurrentPageAudio {
                    Button {
                        audioAutoAdvance.toggle()
                    } label: {
                        Image(systemName: audioAutoAdvance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        audioAutoAdvance.isEnabled
                            ? "Wyłącz automatyczne audio modlitwy"
                            : "Włącz automatyczne audio modlitwy"
                    )
                }

                if routes.hasAlternativeRoute || controller.player.isExternalPlaybackActive {
                    PrayerAirPlayRoutePicker()
                        .frame(width: 36, height: 36)
                        .accessibilityLabel("AirPlay")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
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
        picker.player = PrayerExternalDisplayController.shared.player
        picker.prioritizesVideoDevices = true
        picker.isRoutePickerButtonBordered = false
        picker.tintColor = .label
        picker.activeTintColor = .systemBlue
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        if picker.player !== PrayerExternalDisplayController.shared.player {
            picker.player = PrayerExternalDisplayController.shared.player
        }
    }

    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            Task { @MainActor in
                PrayerExternalDisplayController.shared.prepareForAirPlay()
            }
        }
    }
}
#endif
