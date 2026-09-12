import SwiftUI
internal import Combine

@MainActor
final class PrayerAutoAdvanceTrainingHUDControl: ObservableObject {
    static let shared = PrayerAutoAdvanceTrainingHUDControl()

    @Published var isExpanded = false
    @Published var showingDiagnostics = false

    private var pendingToolbarTap: Task<Void, Never>?

    private init() {}

    /// A real toolbar Button fires once for each physical tap. Delay the single-tap
    /// action briefly so a second tap can promote the gesture to full diagnostics.
    func registerToolbarTap() {
        if let pendingToolbarTap {
            pendingToolbarTap.cancel()
            self.pendingToolbarTap = nil
            showingDiagnostics = true
            return
        }

        pendingToolbarTap = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled, let self else { return }
            self.pendingToolbarTap = nil
            self.isExpanded.toggle()
        }
    }

    func collapseHUD() {
        isExpanded = false
    }

    func showFullDiagnostics() {
        showingDiagnostics = true
    }
}

struct PrayerAutoAdvanceTrainingHUDModifier: ViewModifier {
    @AppStorage(PrayerAutoAdvancePreferences.trainingEnabledKey) private var trainingEnabled = false
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @ObservedObject private var control = PrayerAutoAdvanceTrainingHUDControl.shared

    /// The toolbar indicator reflects the live capture state, not whether training
    /// merely happens to be enabled in preferences.
    private var isCaptureActive: Bool {
        trainingEnabled && diagnostics.speechState == "listening"
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
#if os(iOS)
                if trainingEnabled {
                    ToolbarItem(placement: .topBarLeading) {
                        trainingToolbarButton
                    }
                }
#endif
            }
            .overlay(alignment: .topLeading) {
                if trainingEnabled, control.isExpanded {
                    hud
                        .padding(.leading, 12)
                        .safeAreaPadding(.top, 8)
                }
            }
            .fullScreenCover(isPresented: $control.showingDiagnostics) {
                PrayerAutoAdvanceTrainingDiagnosticsView()
            }
            .onChange(of: trainingEnabled) { _, enabled in
                if !enabled {
                    control.collapseHUD()
                }
            }
    }

#if os(iOS)
    private var trainingToolbarButton: some View {
        Button {
            control.registerToolbarTap()
        } label: {
            Image(systemName: isCaptureActive ? "waveform.badge.mic" : "waveform")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isCaptureActive ? Color.orange : Color.primary)
        }
        .accessibilityLabel(
            isCaptureActive
                ? "Nasłuch treningowy aktywny. Stuknij, aby rozwinąć diagnostykę."
                : "Diagnostyka treningu. Stuknij, aby rozwinąć."
        )
        .accessibilityHint("Stuknij dwa razy, aby otworzyć pełną diagnostykę.")
    }
#endif

    private var hud: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Text("TRAIN")
                Text("E\(diagnostics.currentEpochNumber) \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)p")
                Text("ok \(state.metadata?.trainingSessions ?? 0)")
            }
            HStack(spacing: 7) {
                Text("speech \(diagnostics.speechState)")
                Text("pipe \(diagnostics.pipelineState)")
                Text("snap \(diagnostics.snapshotCount)")
                Text("swipe \(diagnostics.manualSwipeCount)")
            }
            HStack(spacing: 7) {
                if let loss = diagnostics.logLoss {
                    Text(String(format: "loss %.6f", loss))
                } else {
                    Text("loss —")
                }
                if let delta = diagnostics.lastTrainingLossChange {
                    Text(String(format: "Δ %.6f", delta))
                }
                if let movement = diagnostics.lastMeanPredictionDelta {
                    Text(String(format: "|Δp| %.6f", movement))
                }
            }
            HStack(spacing: 7) {
                if let pos = diagnostics.positivePredictionAverage {
                    Text(String(format: "pos %.4f", pos))
                }
                if let neg = diagnostics.negativePredictionAverage {
                    Text(String(format: "neg %.4f", neg))
                }
                if let margin = diagnostics.predictionMargin {
                    Text(String(format: "margin %+.4f", margin))
                }
                Text("P/N \(diagnostics.positiveSamples)/\(diagnostics.negativeSamples)")
            }
            HStack(spacing: 7) {
                Text("stored \(state.storedTrainingPageCount)/\(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)p")
                Text("val \(state.validationStore.records.count)r/\(state.validationStore.sampleCount)s")
                if let loss = diagnostics.currentValidationLoss {
                    Text(String(format: "Vloss %.5f", loss))
                }
                if let margin = diagnostics.currentValidationMargin {
                    Text(String(format: "Vmargin %+.4f", margin))
                }
            }
            Text("1× zwiń · 2× pełna diagnostyka")
                .opacity(0.8)
        }
        .font(.system(size: 8, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .gesture(hudGesture)
        .accessibilityLabel("Diagnostyka treningu. Stuknij, aby zwinąć; stuknij dwa razy, aby otworzyć szczegóły.")
    }

    private var hudGesture: some Gesture {
        ExclusiveGesture(
            TapGesture(count: 2),
            TapGesture(count: 1)
        )
        .onEnded { value in
            switch value {
            case .first:
                control.showFullDiagnostics()
            case .second:
                control.collapseHUD()
            }
        }
    }
}

extension View {
    func prayerAutoAdvanceTrainingHUD() -> some View {
        modifier(PrayerAutoAdvanceTrainingHUDModifier())
    }
}
