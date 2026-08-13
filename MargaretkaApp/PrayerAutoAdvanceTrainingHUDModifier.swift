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
                            Text("speech \(diagnostics.speechState)")
                            Text("pipeline \(diagnostics.pipelineState)")
                        }
                        HStack(spacing: 7) {
                            Text("timing \(state.timingHistory.values.count)/\(PrayerAutoAdvanceTimingHistory.minimumCountForOutliers)")
                            Text("skip \(diagnostics.skippedTrainingCount)")
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
                        if let error = state.lastError {
                            Text("ERR: \(error)")
                                .foregroundStyle(.red)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(diagnostics.recentMessages.suffix(3).enumerated()), id: \.offset) { _, message in
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
