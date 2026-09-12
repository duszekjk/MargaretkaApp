import Charts
import Foundation
import SwiftUI
internal import Combine

struct PrayerAutoAdvanceTrainingQualityMetric: Codable, Sendable, Identifiable {
    let id: Int
    let date: Date
    let freshPageCount: Int
    let replayPageCount: Int
    let sampleCount: Int
    let accuracy: Double
    let balancedAccuracy: Double
    let precision: Double
    let recall: Double
    let specificity: Double
    let f1: Double
    let brierScore: Double
    let logLoss: Double
    let timingPageCount: Int
    let timingMAE: Double?
    let timingMedianAbsoluteError: Double?
    let timingBias: Double?
    let timingHitQuarterSecond: Double?
    let timingHitHalfSecond: Double?
    let timingHitOneSecond: Double?
}

@MainActor
final class PrayerAutoAdvanceTrainingQualityDiagnostics: ObservableObject {
    static let shared = PrayerAutoAdvanceTrainingQualityDiagnostics()
    private static let storageKey = "PrayerAutoAdvanceTrainingQualityHistoryV1"
    private static let maximumHistoryCount = 100

    @Published private(set) var history: [PrayerAutoAdvanceTrainingQualityMetric] = []

    var latest: PrayerAutoAdvanceTrainingQualityMetric? { history.last }

    private init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([PrayerAutoAdvanceTrainingQualityMetric].self, from: data) else {
            return
        }
        history = decoded
    }

    func record(
        pages: [PrayerAutoAdvancePendingTrainingPage],
        model: PrayerAutoAdvanceCoreMLModel,
        freshPageCount: Int,
        replayPageCount: Int
    ) async {
        let evaluation = await Task.detached(priority: .utility) {
            PrayerAutoAdvanceTrainingQualityEvaluator.evaluate(pages: pages, model: model)
        }.value
        guard let evaluation else { return }

        let metric = PrayerAutoAdvanceTrainingQualityMetric(
            id: (history.last?.id ?? 0) + 1,
            date: Date(),
            freshPageCount: freshPageCount,
            replayPageCount: replayPageCount,
            sampleCount: evaluation.sampleCount,
            accuracy: evaluation.accuracy,
            balancedAccuracy: evaluation.balancedAccuracy,
            precision: evaluation.precision,
            recall: evaluation.recall,
            specificity: evaluation.specificity,
            f1: evaluation.f1,
            brierScore: evaluation.brierScore,
            logLoss: evaluation.logLoss,
            timingPageCount: evaluation.timingErrors.count,
            timingMAE: average(evaluation.timingErrors.map(abs)),
            timingMedianAbsoluteError: median(evaluation.timingErrors.map(abs)),
            timingBias: average(evaluation.timingErrors),
            timingHitQuarterSecond: hitRate(evaluation.timingErrors, tolerance: 0.25),
            timingHitHalfSecond: hitRate(evaluation.timingErrors, tolerance: 0.5),
            timingHitOneSecond: hitRate(evaluation.timingErrors, tolerance: 1.0)
        )
        history.append(metric)
        if history.count > Self.maximumHistoryCount {
            history.removeFirst(history.count - Self.maximumHistoryCount)
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func hitRate(_ errors: [Double], tolerance: Double) -> Double? {
        guard !errors.isEmpty else { return nil }
        return Double(errors.filter { abs($0) <= tolerance }.count) / Double(errors.count)
    }
}

private struct PrayerAutoAdvanceTrainingQualityEvaluation: Sendable {
    let sampleCount: Int
    let accuracy: Double
    let balancedAccuracy: Double
    let precision: Double
    let recall: Double
    let specificity: Double
    let f1: Double
    let brierScore: Double
    let logLoss: Double
    let timingErrors: [Double]
}

private enum PrayerAutoAdvanceTrainingQualityEvaluator {
    static func evaluate(
        pages: [PrayerAutoAdvancePendingTrainingPage],
        model: PrayerAutoAdvanceCoreMLModel
    ) -> PrayerAutoAdvanceTrainingQualityEvaluation? {
        var tp = 0
        var tn = 0
        var fp = 0
        var fn = 0
        var brierSum = 0.0
        var lossSum = 0.0
        var sampleCount = 0
        var timingErrors: [Double] = []

        for page in pages {
            var timedPredictions: [(time: Double, probability: Double)] = []
            for sample in page.samples {
                guard let raw = try? model.prediction(
                    for: sample.features,
                    longAudioFeatures: sample.longAudioFeatures
                ) else { continue }
                let probability = min(max(Double(raw), 1e-6), 1 - 1e-6)
                let target = sample.label == 1 ? 1.0 : 0.0
                let predictedPositive = probability >= 0.5
                if sample.label == 1 {
                    if predictedPositive { tp += 1 } else { fn += 1 }
                    lossSum += -log(probability)
                } else {
                    if predictedPositive { fp += 1 } else { tn += 1 }
                    lossSum += -log(1 - probability)
                }
                let difference = probability - target
                brierSum += difference * difference
                sampleCount += 1
                if let relativeTime = sample.relativeTimeToAdvance, relativeTime.isFinite {
                    timedPredictions.append((relativeTime, probability))
                }
            }

            if let crossing = thresholdCrossing(in: timedPredictions) {
                // Ground truth swipe is t=0, so the crossing itself is the signed error.
                timingErrors.append(crossing)
            }
        }

        guard sampleCount > 0 else { return nil }
        let positiveCount = tp + fn
        let negativeCount = tn + fp
        let recall = ratio(tp, positiveCount)
        let specificity = ratio(tn, negativeCount)
        let precision = ratio(tp, tp + fp)
        let f1 = (precision + recall) > 0 ? 2 * precision * recall / (precision + recall) : 0

        return PrayerAutoAdvanceTrainingQualityEvaluation(
            sampleCount: sampleCount,
            accuracy: ratio(tp + tn, sampleCount),
            balancedAccuracy: (recall + specificity) / 2,
            precision: precision,
            recall: recall,
            specificity: specificity,
            f1: f1,
            brierScore: brierSum / Double(sampleCount),
            logLoss: lossSum / Double(sampleCount),
            timingErrors: timingErrors
        )
    }

    private static func thresholdCrossing(
        in values: [(time: Double, probability: Double)]
    ) -> Double? {
        let ordered = values.sorted { $0.time < $1.time }
        guard let upperIndex = ordered.firstIndex(where: { $0.probability >= 0.5 }) else {
            return nil
        }
        let upper = ordered[upperIndex]
        guard upperIndex > 0 else { return upper.time }
        let lower = ordered[upperIndex - 1]
        guard lower.probability < 0.5,
              upper.probability > lower.probability else {
            return upper.time
        }
        let fraction = (0.5 - lower.probability) / (upper.probability - lower.probability)
        return lower.time + fraction * (upper.time - lower.time)
    }

    private static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }
}

struct PrayerAutoAdvanceTrainingQualityView: View {
    @ObservedObject private var quality = PrayerAutoAdvanceTrainingQualityDiagnostics.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let latest = quality.latest {
                    metricsCard(latest)
                    classificationChart
                    timingErrorChart
                    hitRateChart
                    batchCompositionChart
                } else {
                    ContentUnavailableView(
                        "Brak pomiarów jakości",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Metryki pojawią się po następnym udanym zbiorczym treningu.")
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Jakość treningu")
    }

    private func metricsCard(_ metric: PrayerAutoAdvanceTrainingQualityMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ostatni trening").font(.headline)
            row("Nowe / replay", "\(metric.freshPageCount) / \(metric.replayPageCount) stron")
            row("Próbki", "\(metric.sampleCount)")
            row("Accuracy", percent(metric.accuracy))
            row("Balanced accuracy", percent(metric.balancedAccuracy))
            row("Precision", percent(metric.precision))
            row("Recall", percent(metric.recall))
            row("Specificity", percent(metric.specificity))
            row("F1", percent(metric.f1))
            row("Brier score", String(format: "%.6f", metric.brierScore))
            row("Log loss", String(format: "%.6f", metric.logLoss))
            row("Timing pages", "\(metric.timingPageCount)")
            row("Timing MAE", seconds(metric.timingMAE))
            row("Timing median AE", seconds(metric.timingMedianAbsoluteError))
            row("Timing bias", signedSeconds(metric.timingBias))
            row("Hit ±0.25 s", percent(metric.timingHitQuarterSecond))
            row("Hit ±0.5 s", percent(metric.timingHitHalfSecond))
            row("Hit ±1.0 s", percent(metric.timingHitOneSecond))
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var classificationChart: some View {
        chartCard("Klasyfikacja") {
            Chart(quality.history) { metric in
                LineMark(x: .value("Update", metric.id), y: .value("Accuracy", metric.accuracy), series: .value("Seria", "accuracy"))
                LineMark(x: .value("Update", metric.id), y: .value("Balanced", metric.balancedAccuracy), series: .value("Seria", "balanced"))
                LineMark(x: .value("Update", metric.id), y: .value("F1", metric.f1), series: .value("Seria", "F1"))
            }
            .chartYScale(domain: 0...1)
            .frame(height: 260)
        }
    }

    private var timingErrorChart: some View {
        chartCard("Błąd czasu przejścia") {
            Chart(quality.history) { metric in
                if let mae = metric.timingMAE {
                    LineMark(x: .value("Update", metric.id), y: .value("Sekundy", mae), series: .value("Seria", "MAE"))
                }
                if let bias = metric.timingBias {
                    LineMark(x: .value("Update", metric.id), y: .value("Sekundy", bias), series: .value("Seria", "bias"))
                }
            }
            .frame(height: 260)
        }
    }

    private var hitRateChart: some View {
        chartCard("Trafienie czasu") {
            Chart(quality.history) { metric in
                if let value = metric.timingHitQuarterSecond {
                    LineMark(x: .value("Update", metric.id), y: .value("Hit", value), series: .value("Seria", "±0.25 s"))
                }
                if let value = metric.timingHitHalfSecond {
                    LineMark(x: .value("Update", metric.id), y: .value("Hit", value), series: .value("Seria", "±0.5 s"))
                }
                if let value = metric.timingHitOneSecond {
                    LineMark(x: .value("Update", metric.id), y: .value("Hit", value), series: .value("Seria", "±1.0 s"))
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 260)
        }
    }

    private var batchCompositionChart: some View {
        chartCard("Nowe dane i replay") {
            Chart(quality.history) { metric in
                BarMark(x: .value("Update", metric.id), y: .value("Strony", metric.freshPageCount))
                    .foregroundStyle(by: .value("Typ", "nowe"))
                BarMark(x: .value("Update", metric.id), y: .value("Strony", metric.replayPageCount))
                    .foregroundStyle(by: .value("Typ", "replay"))
            }
            .frame(height: 240)
        }
    }

    @ViewBuilder
    private func chartCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value * 100)
    }

    private func seconds(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.3f s", value)
    }

    private func signedSeconds(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.3f s", value)
    }
}
