import SwiftUI

struct PrayerAutoAdvanceTrainingHUDModifier: ViewModifier {
    @AppStorage(PrayerAutoAdvancePreferences.trainingEnabledKey) private var trainingEnabled = false
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if trainingEnabled {
                GeometryReader { proxy in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("TRAIN")
                            Text(String(format: "pred %.3f", diagnostics.predictionHistory.last ?? 0))
                            Text("snap \(diagnostics.snapshotCount)")
                            Text("swipe \(diagnostics.manualSwipeCount)")
                        }
                        HStack(spacing: 7) {
                            Text("ok \(state.metadata?.trainingSessions ?? 0)")
                            Text("skip \(diagnostics.skippedTrainingCount)")
                            Text("speech \(diagnostics.speechState)")
                        }
                        HStack(spacing: 7) {
                            Text("pipe \(diagnostics.pipelineState)")
                            Text("timing \(state.timingHistory.values.count)/\(PrayerAutoAdvanceTimingHistory.minimumCountForOutliers)")
                            Text("P/N \(diagnostics.positiveSamples)/\(diagnostics.negativeSamples)")
                        }

                        HStack(spacing: 7) {
                            Text("E\(diagnostics.currentEpochNumber) \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)")
                            if let margin = diagnostics.currentEpochMarginAverage {
                                Text(String(format: "E margin %+.3f", margin))
                            } else {
                                Text("E margin —")
                            }
                            if let previous = diagnostics.previousEpochMargin {
                                Text(String(format: "prev %+.3f", previous))
                            }
                        }

                        if !diagnostics.completedEpochMargins.isEmpty || diagnostics.currentEpochMarginAverage != nil {
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(Array(diagnostics.completedEpochMargins.suffix(12).enumerated()), id: \.offset) { _, margin in
                                    VStack(spacing: 1) {
                                        Text(margin >= 0 ? "+" : "−")
                                            .font(.system(size: 6, design: .monospaced))
                                        Rectangle()
                                            .frame(width: 5, height: max(2, min(22, CGFloat(abs(margin)) * 22)))
                                    }
                                }
                                if let current = diagnostics.currentEpochMarginAverage {
                                    VStack(spacing: 1) {
                                        Text("*")
                                            .font(.system(size: 6, design: .monospaced))
                                        Rectangle()
                                            .frame(width: 5, height: max(2, min(22, CGFloat(abs(current)) * 22)))
                                    }
                                }
                            }
                            .frame(height: 31, alignment: .bottom)
                        }

                        if let pos = diagnostics.positivePredictionAverage,
                           let neg = diagnostics.negativePredictionAverage,
                           let margin = diagnostics.predictionMargin {
                            HStack(spacing: 7) {
                                Text(String(format: "pos %.3f", pos))
                                Text(String(format: "neg %.3f", neg))
                                Text(String(format: "batch %+.3f", margin))
                            }
                        }

                        HStack(spacing: 7) {
                            if let loss = diagnostics.logLoss {
                                Text(String(format: "loss %.4f", loss))
                            }
                            if let delta = diagnostics.lastTrainingLossChange {
                                Text(String(format: "Δloss %+.4f", delta))
                            }
                            if let peak = diagnostics.lastPeakPrediction {
                                Text(String(format: "peak %.3f", peak))
                            }
                        }

                        if let mae = diagnostics.timingMAE,
                           let bias = diagnostics.timingBias {
                            HStack(spacing: 7) {
                                Text(String(format: "MAE %.2fs", mae))
                                Text(String(format: "bias %+.2fs", bias))
                                if let hit = diagnostics.timingHitOneSecond {
                                    Text(String(format: "±1s %.0f%%", hit * 100))
                                }
                            }
                            HStack(spacing: 7) {
                                if let hit = diagnostics.timingHitHalfSecond {
                                    Text(String(format: "±0.5s %.0f%%", hit * 100))
                                }
                                if let hit = diagnostics.timingHitTwoSeconds {
                                    Text(String(format: "±2s %.0f%%", hit * 100))
                                }
                                if let error = diagnostics.lastPeakTimingError {
                                    Text(String(format: "last %+.2fs", error))
                                }
                            }
                        }

                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(Array(diagnostics.predictionHistory.suffix(28).enumerated()), id: \.offset) { _, value in
                                Rectangle().frame(width: 2, height: max(1, CGFloat(value) * 20))
                            }
                        }
                        .frame(height: 20, alignment: .bottom)

                        Text(diagnostics.lastFeatureSummary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let event = state.lastTrainingEvent {
                            Text(event)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let error = state.lastError {
                            Text("ERR: \(error)")
                                .foregroundStyle(.red)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(diagnostics.recentMessages.suffix(2).enumerated()), id: \.offset) { _, message in
                            Text(message)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(6)
                    .frame(width: max(0, proxy.size.width - 24), alignment: .leading)
                    .background(.black.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.horizontal, 12)
                    .safeAreaPadding(.top, 8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func prayerAutoAdvanceTrainingHUD() -> some View {
        modifier(PrayerAutoAdvanceTrainingHUDModifier())
    }
}
