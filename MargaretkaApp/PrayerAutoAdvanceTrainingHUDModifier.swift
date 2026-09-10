import SwiftUI

struct PrayerAutoAdvanceTrainingHUDModifier: ViewModifier {
    @AppStorage(PrayerAutoAdvancePreferences.trainingEnabledKey) private var trainingEnabled = false
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @State private var showingDiagnostics = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if trainingEnabled {
                    hud
                        .padding(.horizontal, 12)
                        .safeAreaPadding(.top, 8)
                }
            }
            .fullScreenCover(isPresented: $showingDiagnostics) {
                PrayerAutoAdvanceTrainingDiagnosticsView()
            }
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
            Text("2× stuknij, aby otworzyć pełną diagnostykę")
                .opacity(0.8)
        }
        .font(.system(size: 8, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture(count: 2) {
            showingDiagnostics = true
        }
        .accessibilityLabel("Diagnostyka treningu. Stuknij dwa razy, aby otworzyć szczegóły.")
    }
}

extension View {
    func prayerAutoAdvanceTrainingHUD() -> some View {
        modifier(PrayerAutoAdvanceTrainingHUDModifier())
    }
}
