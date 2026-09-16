import Charts
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

    func showTrainingProgress() {
        isExpanded = true
    }
}

struct PrayerAutoAdvanceTrainingHUDModifier: ViewModifier {
    @AppStorage(PrayerAutoAdvancePreferences.trainingEnabledKey) private var trainingEnabled = false
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @ObservedObject private var liveProgress = PrayerAutoAdvanceLiveTrainingProgress.shared
    @ObservedObject private var control = PrayerAutoAdvanceTrainingHUDControl.shared

    private var isListening: Bool {
        trainingEnabled && diagnostics.speechState == "listening"
    }

    private var isMicrophoneActive: Bool {
        isListening && state.microphoneSignalActive
    }

    private var isProcessingPageData: Bool {
        diagnostics.pipelineState == "materializing"
    }

    private var microphoneScale: CGFloat {
        guard isListening else { return 1 }
        return 1 + CGFloat(min(max(state.microphoneActivityLevel, 0), 1)) * 0.11
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
                        // Keep the panel completely below the top-bar button. The
                        // safe-area padding alone starts at the same vertical band as
                        // the toolbar, so the button used to cover the first HUD rows.
                        .safeAreaPadding(.top, 8)
                        .padding(.top, 44)
                }
            }
            .fullScreenCover(isPresented: $control.showingDiagnostics) {
                PrayerAutoAdvanceTrainingDiagnosticsView()
            }
            .onAppear {
                if state.isTraining {
                    control.showTrainingProgress()
                }
            }
            .onChange(of: trainingEnabled) { _, enabled in
                if !enabled {
                    state.resetMicrophoneActivity()
                    control.collapseHUD()
                }
            }
            .onChange(of: state.isTraining) { _, training in
                if training {
                    control.showTrainingProgress()
                    liveProgress.prepare()
                } else if state.lastError != nil {
                    liveProgress.fail()
                } else {
                    liveProgress.finish()
                }
            }
    }

#if os(iOS)
    private var trainingToolbarButton: some View {
        Button {
            control.registerToolbarTap()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: isListening ? "waveform.badge.mic" : "waveform")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isMicrophoneActive ? Color.orange : Color.primary)
                    .scaleEffect(microphoneScale)
                    .animation(.easeOut(duration: 0.16), value: isMicrophoneActive)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: microphoneScale)

                if isProcessingPageData {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.62)
                        .offset(x: 5, y: 5)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isProcessingPageData)
        }
        .accessibilityLabel(toolbarAccessibilityLabel)
        .accessibilityHint("Stuknij dwa razy, aby otworzyć pełną diagnostykę.")
    }

    private var toolbarAccessibilityLabel: String {
        if isProcessingPageData {
            return "Przetwarzanie i zapisywanie danych strony. Stuknij, aby rozwinąć diagnostykę."
        }
        if isMicrophoneActive {
            return "Mikrofon odbiera mowę. Stuknij, aby rozwinąć diagnostykę."
        }
        if isListening {
            return "Mikrofon nasłuchuje, ale nie wykrywa teraz mowy. Stuknij, aby rozwinąć diagnostykę."
        }
        return "Diagnostyka treningu. Stuknij, aby rozwinąć."
    }
#endif

    private var hud: some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.isTraining || liveProgress.isActive {
                liveTrainingSection
                Divider()
                    .overlay(.white.opacity(0.25))
            }

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
                Text(String(format: "mic %.2f", state.microphoneActivityLevel))
                Text(state.microphoneSignalActive ? "voice yes" : "voice no")
                if isProcessingPageData {
                    Text("page save…")
                }
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
        .padding(7)
        .frame(maxWidth: 330, alignment: .leading)
        .background(.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .gesture(hudGesture)
        .accessibilityLabel("Diagnostyka treningu. Stuknij, aby zwinąć; stuknij dwa razy, aby otworzyć szczegóły.")
    }

    private var liveTrainingSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(liveProgress.stage)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "%.0f%%", liveProgress.progress * 100))
                    .monospacedDigit()
            }

            ProgressView(value: liveProgress.progress, total: 1)
                .tint(.white)

            HStack(spacing: 8) {
                if liveProgress.epochCount > 0 {
                    Text("epoka \(liveProgress.currentEpoch)/\(liveProgress.epochCount)")
                }
                if liveProgress.totalSteps > 0 {
                    Text("krok \(liveProgress.completedSteps)/\(liveProgress.totalSteps)")
                }
                if let loss = liveProgress.currentLoss {
                    Text(String(format: "loss %.6f", loss))
                }
            }

            HStack(spacing: 8) {
                Text("czas \(durationText(liveProgress.elapsed))")
                if let remaining = liveProgress.estimatedRemaining {
                    Text("ETA ~\(durationText(remaining))")
                } else {
                    Text("ETA —")
                }
            }

            if liveProgress.lossHistory.count >= 2 {
                trainingLossChart
            }
        }
    }

    private var trainingLossChart: some View {
        let points = Array(liveProgress.lossHistory.suffix(80))
        return Chart(points) { point in
            LineMark(
                x: .value("Krok", point.step),
                y: .value("Loss", point.loss)
            )
            .interpolationMethod(.linear)

            if point.id == points.last?.id {
                PointMark(
                    x: .value("Krok", point.step),
                    y: .value("Loss", point.loss)
                )
                .symbolSize(22)
                .annotation(position: .top, spacing: 2) {
                    Text(String(format: "%.4f", point.loss))
                        .font(.system(size: 7, design: .monospaced))
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                    .foregroundStyle(.white.opacity(0.16))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.5))
                AxisValueLabel {
                    if let step = value.as(Int.self) {
                        Text("\(step)")
                    }
                }
                .font(.system(size: 6, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                    .foregroundStyle(.white.opacity(0.16))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.5))
                AxisValueLabel {
                    if let loss = value.as(Double.self) {
                        Text(String(format: "%.3f", loss))
                    }
                }
                .font(.system(size: 6, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(height: 108)
        .accessibilityLabel("Wykres loss na żywo podczas treningu")
    }

    private func durationText(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval >= 0 else { return "—" }
        let seconds = Int(interval.rounded())
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
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
