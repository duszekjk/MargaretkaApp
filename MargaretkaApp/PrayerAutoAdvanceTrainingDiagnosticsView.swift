import Charts
import SwiftUI

struct PrayerAutoAdvanceTrainingDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    summary
                    PrayerAutoAdvanceTrainingInputSamplesView()
                    currentEpochLossChart
                    currentEpochValidationLossChart
                    epochLossChart
                    lossDeltaChart
                    predictionMovementChart
                    currentEpochMarginChart
                    epochMarginChart
                    classProbabilityChart
                    batchCompositionChart
                    timingSummary
                    recentEvents
                }
                .padding()
            }
            .navigationTitle("Diagnostyka treningu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
    }

    private var summary: some View {
        diagnosticsCard("Stan") {
            metricRow("Model", state.metadata.map { "v\($0.baseModelVersion) / schema v\($0.featureSchemaVersion)" } ?? "—")
            metricRow("Epoka", "\(diagnostics.currentEpochNumber), krok \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)")
            metricRow("Aktualizacje", "\(diagnostics.updateHistory.count) zapisanych")
            metricRow("Loss", formatted(diagnostics.logLoss, digits: 8))
            metricRow("Δloss", signed(diagnostics.lastTrainingLossChange, digits: 8))
            metricRow("Mean |Δpred|", formatted(diagnostics.lastMeanPredictionDelta, digits: 8))
            metricRow("Max |Δpred|", formatted(diagnostics.lastMaxPredictionDelta, digits: 8))
            metricRow("Train margin", diagnostics.predictionMargin.map { String(format: "%+.6f", $0) } ?? "—")
            metricRow("Validation loss", formatted(diagnostics.currentValidationLoss, digits: 8))
            metricRow("Validation margin", signed(diagnostics.currentValidationMargin, digits: 6))
        }
    }

    private var currentEpochLossChart: some View {
        chartCard("Loss — bieżąca epoka", subtitle: "Cross-entropy przed i po każdej lokalnej aktualizacji. Obie serie powinny się rozchodzić, jeśli update zmienia model.") {
            Chart(diagnostics.currentEpochUpdates) { point in
                LineMark(
                    x: .value("Krok", point.positionInEpoch),
                    y: .value("Loss", point.lossBefore),
                    series: .value("Seria", "przed")
                )
                .foregroundStyle(by: .value("Seria", "przed"))
                PointMark(x: .value("Krok", point.positionInEpoch), y: .value("Loss", point.lossBefore))
                    .foregroundStyle(by: .value("Seria", "przed"))

                LineMark(
                    x: .value("Krok", point.positionInEpoch),
                    y: .value("Loss", point.lossAfter),
                    series: .value("Seria", "po")
                )
                .foregroundStyle(by: .value("Seria", "po"))
                PointMark(x: .value("Krok", point.positionInEpoch), y: .value("Loss", point.lossAfter))
                    .foregroundStyle(by: .value("Seria", "po"))
            }
            .frame(height: 280)
        }
    }

    private var currentEpochValidationLossChart: some View {
        chartCard("Validation loss — bieżąca epoka", subtitle: "Loss na lokalnym holdoucie po każdej aktualizacji; nie jest używany do backpropagation.") {
            Chart(diagnostics.currentEpochUpdates) { point in
                if let loss = point.validationLoss {
                    LineMark(x: .value("Krok", point.positionInEpoch), y: .value("Validation loss", loss))
                    PointMark(x: .value("Krok", point.positionInEpoch), y: .value("Validation loss", loss))
                }
            }
            .frame(height: 240)
        }
    }

    private var epochLossChart: some View {
        chartCard("Loss — epoka do epoki", subtitle: "Średni training loss ze 100 aktualizacji i validation loss na końcu każdej epoki diagnostycznej.") {
            Chart(diagnostics.completedEpochs) { epoch in
                if let loss = epoch.trainingLoss {
                    LineMark(
                        x: .value("Epoka", epoch.id),
                        y: .value("Loss", loss),
                        series: .value("Seria", "train")
                    )
                    .foregroundStyle(by: .value("Seria", "train"))
                    PointMark(x: .value("Epoka", epoch.id), y: .value("Loss", loss))
                        .foregroundStyle(by: .value("Seria", "train"))
                }
                if let loss = epoch.validationLoss {
                    LineMark(
                        x: .value("Epoka", epoch.id),
                        y: .value("Loss", loss),
                        series: .value("Seria", "validation")
                    )
                    .foregroundStyle(by: .value("Seria", "validation"))
                    PointMark(x: .value("Epoka", epoch.id), y: .value("Loss", loss))
                        .foregroundStyle(by: .value("Seria", "validation"))
                }
            }
            .frame(height: 280)
        }
    }

    private var lossDeltaChart: some View {
        chartCard("Δloss po aktualizacji", subtitle: "Dodatnia wartość oznacza spadek loss na batchu treningowym po MLUpdateTask.") {
            Chart {
                ForEach(diagnostics.updateHistory.suffix(300)) { point in
                    LineMark(x: .value("Aktualizacja", point.id), y: .value("Δloss", point.lossDelta))
                    PointMark(x: .value("Aktualizacja", point.id), y: .value("Δloss", point.lossDelta))
                }
                RuleMark(y: .value("Zero", 0.0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .frame(height: 240)
        }
    }

    private var predictionMovementChart: some View {
        chartCard("Ruch predykcji po backprop", subtitle: "Średnia i maksymalna bezwzględna zmiana P(advance) na tym samym batchu przed/po update.") {
            Chart(diagnostics.updateHistory.suffix(300)) { point in
                LineMark(
                    x: .value("Aktualizacja", point.id),
                    y: .value("|Δpred|", point.meanPredictionDelta),
                    series: .value("Seria", "średnia")
                )
                .foregroundStyle(by: .value("Seria", "średnia"))
                LineMark(
                    x: .value("Aktualizacja", point.id),
                    y: .value("|Δpred|", point.maxPredictionDelta),
                    series: .value("Seria", "maksimum")
                )
                .foregroundStyle(by: .value("Seria", "maksimum"))
            }
            .frame(height: 240)
        }
    }

    private var currentEpochMarginChart: some View {
        chartCard("Margin — bieżąca epoka", subtitle: "Train i validation margin po kolejnych update'ach w tej samej epoce diagnostycznej.") {
            Chart(diagnostics.currentEpochUpdates) { point in
                if let margin = point.trainingMargin {
                    LineMark(
                        x: .value("Krok", point.positionInEpoch),
                        y: .value("Margin", margin),
                        series: .value("Seria", "train")
                    )
                    .foregroundStyle(by: .value("Seria", "train"))
                }
                if let margin = point.validationMargin {
                    LineMark(
                        x: .value("Krok", point.positionInEpoch),
                        y: .value("Margin", margin),
                        series: .value("Seria", "validation")
                    )
                    .foregroundStyle(by: .value("Seria", "validation"))
                }
            }
            .frame(height: 240)
        }
    }

    private var epochMarginChart: some View {
        chartCard("Margin — epoka do epoki", subtitle: "Wzrost train bez validation jest klasycznym sygnałem overfittingu.") {
            Chart(diagnostics.completedEpochs) { epoch in
                LineMark(
                    x: .value("Epoka", epoch.id),
                    y: .value("Margin", epoch.trainingMargin),
                    series: .value("Seria", "train")
                )
                .foregroundStyle(by: .value("Seria", "train"))
                PointMark(x: .value("Epoka", epoch.id), y: .value("Margin", epoch.trainingMargin))
                    .foregroundStyle(by: .value("Seria", "train"))
                if let validation = epoch.validationMargin {
                    LineMark(
                        x: .value("Epoka", epoch.id),
                        y: .value("Margin", validation),
                        series: .value("Seria", "validation")
                    )
                    .foregroundStyle(by: .value("Seria", "validation"))
                    PointMark(x: .value("Epoka", epoch.id), y: .value("Margin", validation))
                        .foregroundStyle(by: .value("Seria", "validation"))
                }
            }
            .frame(height: 260)
        }
    }

    private var classProbabilityChart: some View {
        chartCard("Separacja klas", subtitle: "Średnie P(advance) dla pozytywnych i negatywnych próbek. Docelowo positive → 1, negative → 0.") {
            Chart(diagnostics.updateHistory.suffix(300)) { point in
                if let value = point.positiveAverage {
                    LineMark(
                        x: .value("Aktualizacja", point.id),
                        y: .value("P(advance)", value),
                        series: .value("Klasa", "positive")
                    )
                    .foregroundStyle(by: .value("Klasa", "positive"))
                }
                if let value = point.negativeAverage {
                    LineMark(
                        x: .value("Aktualizacja", point.id),
                        y: .value("P(advance)", value),
                        series: .value("Klasa", "negative")
                    )
                    .foregroundStyle(by: .value("Klasa", "negative"))
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 260)
        }
    }

    private var batchCompositionChart: some View {
        chartCard("Skład batcha", subtitle: "Pozytywne próbki nad osią, negatywne pod osią.") {
            Chart(diagnostics.updateHistory.suffix(200)) { point in
                BarMark(x: .value("Aktualizacja", point.id), y: .value("Próbki", point.positiveCount))
                    .foregroundStyle(by: .value("Klasa", "positive"))
                BarMark(x: .value("Aktualizacja", point.id), y: .value("Próbki", -point.negativeCount))
                    .foregroundStyle(by: .value("Klasa", "negative"))
            }
            .frame(height: 240)
        }
    }

    private var timingSummary: some View {
        diagnosticsCard("Timing") {
            metricRow("MAE", diagnostics.timingMAE.map { String(format: "%.3f s", $0) } ?? "—")
            metricRow("Bias", diagnostics.timingBias.map { String(format: "%+.3f s", $0) } ?? "—")
            metricRow("Hit ±0.5 s", percent(diagnostics.timingHitHalfSecond))
            metricRow("Hit ±1 s", percent(diagnostics.timingHitOneSecond))
            metricRow("Hit ±2 s", percent(diagnostics.timingHitTwoSeconds))
            metricRow("Kalibracja", "\(state.timingHistory.values.count)/\(PrayerAutoAdvanceTimingHistory.minimumCountForOutliers)")
        }
    }

    private var recentEvents: some View {
        diagnosticsCard("Ostatnie zdarzenia") {
            ForEach(Array(diagnostics.recentMessages.reversed().enumerated()), id: \.offset) { _, message in
                Text(message)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func chartCard<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            content()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func diagnosticsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metricRow(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func formatted(_ value: Double?, digits: Int) -> String {
        guard let value else { return "—" }
        return String(format: "%.*f", digits, value)
    }

    private func signed(_ value: Double?, digits: Int) -> String {
        guard let value else { return "—" }
        return String(format: "%+.*f", digits, value)
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value * 100)
    }
}
