import SwiftUI

struct PrayerAutoAdvanceTrainingHUDModifier: ViewModifier {
    @AppStorage(PrayerAutoAdvancePreferences.trainingEnabledKey) private var trainingEnabled = false
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @State private var showingDiagnostics = false
    @State private var isExpanded = false

    private var isListening: Bool {
        diagnostics.speechState == "listening"
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                if trainingEnabled {
                    Group {
                        if isExpanded {
                            hud
                        } else {
                            collapsedButton
                        }
                    }
                    .padding(.leading, 12)
                    .safeAreaPadding(.top, 8)
                }
            }
            .fullScreenCover(isPresented: $showingDiagnostics) {
                PrayerAutoAdvanceTrainingDiagnosticsView()
            }
    }

    private var collapsedButton: some View {
        Image(systemName: isListening ? "waveform.badge.mic" : "waveform")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isListening ? .orange : .primary)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle()
                    .fill(isListening ? Color.orange.opacity(0.16) : Color.clear)
            }
            .overlay {
                Circle()
                    .strokeBorder(isListening ? Color.orange.opacity(0.55) : Color.white.opacity(0.18), lineWidth: 0.75)
            }
            .contentShape(Circle())
            .gesture(trainingHUDGesture)
            .accessibilityLabel(
                isListening
                    ? "Trening aktywny. Stuknij, aby rozwinąć diagnostykę."
                    : "Diagnostyka treningu. Stuknij, aby rozwinąć."
            )
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Text("TRAIN")
                Text("E\(diagnostics.currentEpochNumber) \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)")
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
        .gesture(trainingHUDGesture)
        .accessibilityLabel("Diagnostyka treningu. Stuknij, aby zwinąć; stuknij dwa razy, aby otworzyć szczegóły.")
    }

    private var trainingHUDGesture: some Gesture {
        ExclusiveGesture(
            TapGesture(count: 2),
            TapGesture(count: 1)
        )
        .onEnded { value in
            switch value {
            case .first:
                showingDiagnostics = true
            case .second:
                isExpanded.toggle()
            }
        }
    }
}

extension View {
    func prayerAutoAdvanceTrainingHUD() -> some View {
        modifier(PrayerAutoAdvanceTrainingHUDModifier())
    }
}
