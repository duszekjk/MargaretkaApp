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
    @AppStorage(PrayerAutoAdvancePreferences.automaticEnabledKey) private var automaticEnabled = false
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @ObservedObject private var liveProgress = PrayerAutoAdvanceLiveTrainingProgress.shared
    @ObservedObject private var quality = PrayerAutoAdvanceTrainingQualityDiagnostics.shared
    @ObservedObject private var control = PrayerAutoAdvanceTrainingHUDControl.shared
    @State private var pendingAutomaticModeSuggestion: PrayerAutoAdvanceTrainingQualityMetric?
    @State private var showingAutomaticModeSuggestion = false

    private var isListening: Bool {
        (trainingEnabled || automaticEnabled) && diagnostics.speechState == "listening"
    }

    private var isMicrophoneActive: Bool {
        isListening && state.microphoneSignalActive
    }

    private var isProcessingPageData: Bool {
        diagnostics.pipelineState == "materializing"
            || diagnostics.pipelineState == "stored"
            || diagnostics.pipelineState == "validation"
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
                VStack(alignment: .leading, spacing: 6) {
                    if automaticEnabled {
                        automaticDiagnosticsPanel
                    }
                    if trainingEnabled, control.isExpanded {
                        hud
                    }
                }
                .padding(.leading, 12)
                .safeAreaPadding(.top, 8)
                .padding(.top, 44)
            }
            .fullScreenCover(isPresented: $control.showingDiagnostics) {
                PrayerAutoAdvanceTrainingDiagnosticsView()
            }
            .alert("Model osiągnął wysoką jakość", isPresented: $showingAutomaticModeSuggestion) {
                Button("Włącz automatyczne przełączanie") {
                    activateAutomaticMode()
                }
                Button("Kontynuuj uczenie", role: .cancel) {
                    pendingAutomaticModeSuggestion = nil
                }
            } message: {
                if let metric = pendingAutomaticModeSuggestion {
                    Text(automaticModeSuggestionMessage(metric))
                }
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
            .onChange(of: quality.latest?.id) { _, _ in
                guard trainingEnabled,
                      let metric = quality.latest,
                      qualifiesForAutomaticMode(metric) else { return }
                pendingAutomaticModeSuggestion = metric
                presentAutomaticModeSuggestionIfReady()
            }
            .onChange(of: state.isTrainingPipelineBusy) { _, _ in
                presentAutomaticModeSuggestionIfReady()
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


    private var automaticDiagnosticsPanel: some View {
        HStack(alignment: .top, spacing: 7) {
            VStack(spacing: 1) {
                predictionGauge
                Text(String(format: "p %.3f", diagnostics.livePrediction))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AUTO DELAY  n=\(diagnostics.automaticAdvanceLatencies.count)")
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    Text("min \(latencyText(diagnostics.automaticLatencyMinimum))")
                    Text("avg \(latencyText(diagnostics.automaticLatencyAverage))")
                }
                HStack(spacing: 6) {
                    Text("max \(latencyText(diagnostics.automaticLatencyMaximum))")
                    Text("var \(varianceText(diagnostics.automaticLatencyVariance))")
                }

                if diagnostics.automaticAdvanceLatencies.count >= 2 {
                    latencySparkline
                }
            }
        }
        .font(.system(size: 7, design: .monospaced))
        .foregroundStyle(.white)
        .padding(5)
        .background(.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Predykcja automatycznego przejścia \(String(format: "%.3f", diagnostics.livePrediction)). "
            + "Średnie opóźnienie \(latencyText(diagnostics.automaticLatencyAverage))."
        )
    }

    private var predictionGauge: some View {
        HStack(alignment: .center, spacing: 2) {
            VStack {
                Text("1")
                Spacer(minLength: 0)
                Text("0")
            }
            .font(.system(size: 5, design: .monospaced))
            .foregroundStyle(.white.opacity(0.8))

            GeometryReader { proxy in
                let probability = CGFloat(min(max(diagnostics.livePrediction, 0), 1))
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(.white.opacity(0.35), lineWidth: 0.5)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(predictionColor)
                        .frame(height: max(1, proxy.size.height * probability))

                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(height: 0.5)
                        .offset(y: -proxy.size.height * 0.96)
                }
            }
            .frame(width: 17, height: 48)
        }
        .frame(width: 28, height: 48)
    }

    private var latencySparkline: some View {
        let values = Array(diagnostics.automaticAdvanceLatencies.suffix(24))
        return Chart(Array(values.enumerated()), id: \.offset) { point in
            LineMark(
                x: .value("Sample", point.offset),
                y: .value("Delay", point.element)
            )
            .interpolationMethod(.catmullRom)

            if point.offset == values.count - 1 {
                PointMark(
                    x: .value("Sample", point.offset),
                    y: .value("Delay", point.element)
                )
                .symbolSize(10)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 92, height: 22)
        .accessibilityLabel("Historia opóźnienia automatycznych przejść")
    }

    private var predictionColor: Color {
        let value = Double(min(max(diagnostics.livePrediction, 0), 1))
        return Color(
            hue: (1 - value) * 0.33,
            saturation: 0.86,
            brightness: 0.96
        )
    }

    private func latencyText(_ value: TimeInterval?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.3fs", value)
    }

    private func varianceText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.4f", value)
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 5) {
            if state.isTraining || liveProgress.isActive {
                liveTrainingSection
                Divider()
                    .overlay(.white.opacity(0.25))
            }

            liveCaptureSection

            Text("1× zwiń · 2× pełna diagnostyka")
                .opacity(0.72)
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

    private var liveCaptureSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Text("CAPTURE")
                    .fontWeight(.semibold)
                Text(isListening ? "mic on" : "mic off")
                Text(state.microphoneSignalActive ? "signal yes" : "signal no")
                Text(String(format: "level %.2f", state.microphoneActivityLevel))
            }

            HStack(spacing: 7) {
                Text("fresh \(state.storedTrainingPageCount)/\(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)")
                Text("queued \(state.queuedTrainingPageCount)")
                Text("replay \(state.replayTrainingPageCount)")
            }

            HStack(spacing: 7) {
                Text("pipe \(diagnostics.pipelineState)")
                Text("swipes \(diagnostics.manualSwipeCount)")
                if isProcessingPageData {
                    Text("saving…")
                }
            }
        }
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
            .interpolationMethod(.catmullRom)

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

    private func qualifiesForAutomaticMode(_ metric: PrayerAutoAdvanceTrainingQualityMetric) -> Bool {
        guard metric.sampleCount >= 100,
              metric.accuracy >= 0.95,
              metric.balancedAccuracy >= 0.95,
              metric.f1 >= 0.95 else {
            return false
        }

        // Timing remains part of the real product behavior, but a 95% threshold
        // tolerates a few mislabeled/manual transitions while still requiring
        // consistently good automatic switching once enough timing observations exist.
        if metric.timingPageCount >= 50 {
            return (metric.timingHitOneSecond ?? 0) >= 0.95
        }
        return true
    }

    private func presentAutomaticModeSuggestionIfReady() {
        guard pendingAutomaticModeSuggestion != nil,
              trainingEnabled,
              !state.isTraining,
              !state.isTrainingPipelineBusy,
              !showingAutomaticModeSuggestion else { return }
        showingAutomaticModeSuggestion = true
    }

    private func automaticModeSuggestionMessage(_ metric: PrayerAutoAdvanceTrainingQualityMetric) -> String {
        var parts = [
            String(format: "Accuracy %.1f%%", metric.accuracy * 100),
            String(format: "balanced %.1f%%", metric.balancedAccuracy * 100),
            String(format: "F1 %.1f%%", metric.f1 * 100),
        ]
        if let hit = metric.timingHitOneSecond, metric.timingPageCount > 0 {
            parts.append(String(format: "timing ±1 s %.1f%%", hit * 100))
        }
        return parts.joined(separator: " • ")
            + ". Wyniki spełniają próg 95%. Czy wyłączyć dalsze uczenie i przełączyć aplikację na automatyczne przełączanie stron?"
    }

    private func activateAutomaticMode() {
        trainingEnabled = false
        automaticEnabled = true
        pendingAutomaticModeSuggestion = nil
        NotificationCenter.default.post(name: .prayerAutoAdvancePreferencesChanged, object: nil)
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
