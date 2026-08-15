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
                            Text("val \(state.validationStore.records.count)r/\(state.validationStore.sampleCount)s")
                        }

                        HStack(spacing: 7) {
                            Text("E\(diagnostics.currentEpochNumber) \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)")
                            if let margin = diagnostics.currentEpochTrainingMarginAverage {
                                Text(String(format: "T %+.3f", margin))
                            } else {
                                Text("T —")
                            }
                            if let margin = diagnostics.currentValidationMargin {
                                Text(String(format: "V %+.3f", margin))
                            } else {
                                Text("V —")
                            }
                        }

                        if let previous = diagnostics.previousEpoch {
                            HStack(spacing: 7) {
                                Text("prev E\(previous.id)")
                                Text(String(format: "T %+.3f", previous.trainingMargin))
                                if let validation = previous.validationMargin {
                                    Text(String(format: "V %+.3f", validation))
                                }
                            }
                        }

                        if diagnostics.completedEpochs.count >= 3 {
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(diagnostics.completedEpochs.suffix(12)) { epoch in
                                    VStack(spacing: 1) {
                                        HStack(alignment: .bottom, spacing: 1) {
                                            Rectangle()
                                                .opacity(0.45)
                                                .frame(width: 3, height: epochHeight(epoch.trainingMargin))
                                            if let validation = epoch.validationMargin {
                                                Rectangle()
                                                    .frame(width: 3, height: epochHeight(validation))
                                            }
                                        }
                                        Text("\(epoch.id)")
                                            .font(.system(size: 5, design: .monospaced))
                                    }
                                }
                            }
                            .frame(height: 34, alignment: .bottom)
                            Text("epochs: T dim / V bright")
                                .font(.system(size: 6, design: .monospaced))
                                .opacity(0.8)
                        }

                        if let pos = diagnostics.positivePredictionAverage,
                           let neg = diagnostics.negativePredictionAverage,
                           let margin = diagnostics.predictionMargin {
                            HStack(spacing: 7) {
                                Text("P/N \(diagnostics.positiveSamples)/\(diagnostics.negativeSamples)")
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

    private func epochHeight(_ margin: Double) -> CGFloat {
        max(2, min(22, CGFloat(abs(margin)) * 22))
    }
}

extension View {
    func prayerAutoAdvanceTrainingHUD() -> some View {
        modifier(PrayerAutoAdvanceTrainingHUDModifier())
    }
}
