#if os(iOS)
import AVFoundation
import AVKit
import SwiftUI

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

    var body: some View {
        if controller.hasCurrentPageAudio || routes.hasAlternativeRoute || controller.player.isExternalPlaybackActive {
            HStack(spacing: 8) {
                if controller.hasCurrentPageAudio {
                    Button {
                        controller.toggleAudioMute()
                    } label: {
                        Image(systemName: controller.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(controller.isAudioMuted ? "Włącz audio modlitwy" : "Wycisz audio modlitwy")
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
