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
    static let prayerExternalPlaybackStateChanged = Notification.Name(
        "margaretka.externalDisplay.playbackStateChanged"
    )
}

@MainActor
final class PrayerExternalPlaybackState: ObservableObject {
    static let shared = PrayerExternalPlaybackState()

    @Published private(set) var isActive = false
    private var observation: NSKeyValueObservation?

    private init() {
        observation = PrayerExternalDisplayController.shared.player.observe(
            \.isExternalPlaybackActive,
            options: [.initial, .new]
        ) { _, change in
            let active = change.newValue ?? false
            Task { @MainActor [weak self] in
                guard let self, self.isActive != active else { return }
                self.isActive = active
                NotificationCenter.default.post(
                    name: .prayerExternalPlaybackStateChanged,
                    object: nil
                )
            }
        }
    }
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

private enum PrayerAirPlayAIWarning: String, Identifiable {
    case training
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .training:
            "AirPlay wstrzymuje trenowanie AI"
        case .automatic:
            "AirPlay wstrzymuje automatyczne przełączanie"
        }
    }

    var message: String {
        switch self {
        case .training:
            "Podczas aktywnego AirPlay trenowanie modelu sztucznej inteligencji jest wyłączone. Funkcja zostanie wznowiona po rozłączeniu AirPlay."
        case .automatic:
            "Podczas aktywnego AirPlay automatyczne przełączanie modlitw przez sztuczną inteligencję jest wyłączone. Funkcja zostanie wznowiona po rozłączeniu AirPlay."
        }
    }

    var suppressionKey: String {
        switch self {
        case .training:
            "prayerAutoAdvance.airPlayTrainingWarningSuppressed"
        case .automatic:
            "prayerAutoAdvance.airPlayAutomaticWarningSuppressed"
        }
    }
}

struct PrayerExternalPlaybackControls: View {
    @StateObject private var routes = PrayerAirPlayRouteAvailability.shared
    @StateObject private var externalPlayback = PrayerExternalPlaybackState.shared
    @ObservedObject private var controller = PrayerExternalDisplayController.shared
    @ObservedObject private var audioAutoAdvance = PrayerAudioAutoAdvanceCoordinator.shared
    @State private var activeWarning: PrayerAirPlayAIWarning?

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

            if routes.hasAlternativeRoute || externalPlayback.isActive {
                PrayerAirPlayRoutePicker()
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("AirPlay")
            }
        }
        .onChange(of: externalPlayback.isActive) { _, active in
            guard active else {
                activeWarning = nil
                return
            }
            presentFirstWarning()
        }
        .alert(item: $activeWarning) { warning in
            Alert(
                title: Text(warning.title),
                message: Text(warning.message),
                primaryButton: .default(Text("OK")) {
                    finishWarning(warning, suppress: false)
                },
                secondaryButton: .default(Text("Nie pokazuj ponownie")) {
                    finishWarning(warning, suppress: true)
                }
            )
        }
    }

    private func presentFirstWarning() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey),
           !defaults.bool(forKey: PrayerAirPlayAIWarning.training.suppressionKey) {
            activeWarning = .training
            return
        }
        if defaults.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey),
           !defaults.bool(forKey: PrayerAirPlayAIWarning.automatic.suppressionKey) {
            activeWarning = .automatic
        }
    }

    private func finishWarning(_ warning: PrayerAirPlayAIWarning, suppress: Bool) {
        if suppress {
            UserDefaults.standard.set(true, forKey: warning.suppressionKey)
        }

        let next: PrayerAirPlayAIWarning?
        switch warning {
        case .training:
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey),
               !defaults.bool(forKey: PrayerAirPlayAIWarning.automatic.suppressionKey) {
                next = .automatic
            } else {
                next = nil
            }
        case .automatic:
            next = nil
        }

        activeWarning = nil
        guard let next else { return }
        DispatchQueue.main.async {
            activeWarning = next
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
                PrayerExternalDisplayController.shared.prepareForAirPlay()
            }
        }
    }
}
#endif
