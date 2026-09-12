import Charts
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PrayerAutoAdvanceTrainingDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @State private var didCopyDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    summary
                    groupedTrainingPipeline
                    PrayerAutoAdvanceTrainingInputSamplesView()
                    currentEpochLossChart
                    currentEpochValidationLossChart
                    epochLossChart
                    lossDeltaChart
                    predictionMovementChart
                    latestBackpropUpdates
                    currentEpochMarginChart
                    epochMarginChart
                    classProbabilityChart
                    batchCompositionChart
                    timingSummary
                    recentEvents
                    trainingTrace
                }
                .padding()
            }
            .navigationTitle("Diagnostyka treningu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        copyDiagnosticsReport()
                    } label: {
                        Label(
                            didCopyDiagnostics ? "Skopiowano" : "Kopiuj diagnostykę",
                            systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc"
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
    }

    private var summary: some View {
        diagnosticsCard("Stan") {
            metricRow("Model", state.metadata.map { "v\($0.baseModelVersion) / schema v\($0.featureSchemaVersion)" } ?? "—")
            metricRow("Pipeline", diagnostics.pipelineState)
            metricRow("Core ML train()", state.isTraining ? "AKTYWNY" : "nieaktywny")
            metricRow("Pipeline zajęty", state.isTrainingPipelineBusy ? "tak" : "nie")
            metricRow("Epoka", "\(diagnostics.currentEpochNumber), strony \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)")
            metricRow("Zbiorcze aktualizacje", "\(diagnostics.updateHistory.count) zapisanych")
            metricRow("Strony oczekujące", "\(state.storedTrainingPageCount)/\(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)")
            metricRow("Loss (cel → 0)", formatted(diagnostics.logLoss, digits: 8))
            metricRow("Δloss (dobrze > 0)", signed(diagnostics.lastTrainingLossChange, digits: 8))
            metricRow("Mean |Δpred|", formatted(diagnostics.lastMeanPredictionDelta, digits: 8))
            metricRow("Max |Δpred|", formatted(diagnostics.lastMaxPredictionDelta, digits: 8))
            metricRow("Backprop", diagnostics.backpropStatus)
            metricRow("Train margin (cel > 0)", diagnostics.predictionMargin.map { String(format: "%+.6f", $0) } ?? "—")
            metricRow("Validation loss (cel ↓)", formatted(diagnostics.currentValidationLoss, digits: 8))
            metricRow("Validation margin (cel > 0)", signed(diagnostics.currentValidationMargin, digits: 6))
        }
    }

    private var groupedTrainingPipeline: some View {
        diagnosticsCard("Pipeline treningu zbiorczego") {
            Text(
                "Sam komunikat o rozpoczęciu treningu nie oznacza jeszcze, że nowy model został zapisany. "
                    + "Poprawny przebieg to: ocena modelu → MLUpdateTask → weryfikacja zmiany predykcji → podmiana modelu → zapis metadanych → usunięcie wykorzystanych stron."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            metricRow("Etap", diagnostics.pipelineState)
            metricRow("Grouped pages", "\(state.groupedTrainingPageCount)")
            metricRow("Stored pages", "\(state.storedTrainingPageCount)")
            metricRow("Queued pages", "\(state.queuedTrainingPageCount)")
            metricRow("Scheduled captures", "\(state.scheduledTrainingCaptureCount)")
            metricRow("Pending in memory", "\(state.pendingTrainingPages.count)")
            metricRow("Koniec modlitwy czeka", state.trainingAtPrayerEndRequested ? "tak" : "nie")
            metricRow("Grouped task", state.groupedTrainingTask == nil ? "brak" : "aktywne")
            metricRow("Queue task", state.trainingQueueTask == nil ? "brak" : "aktywne")

            if let event = state.lastTrainingEvent {
                Text("Ostatni komunikat: \(event)")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = state.lastError {
                Text("BŁĄD: \(error)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var currentEpochLossChart: some View {
        chartCard(
            "Loss — bieżąca epoka",
            subtitle: "Cross-entropy przed i po każdej zbiorczej aktualizacji. Oś X pokazuje łączną liczbę stron w epoce diagnostycznej. Poprawnie: punkt „po” jest zwykle niżej niż „przed”."
        ) {
            Chart(diagnostics.currentEpochUpdates) { point in
                LineMark(
                    x: .value("Strony", point.positionInEpoch),
                    y: .value("Loss", point.lossBefore),
                    series: .value("Seria", "przed")
                )
                .foregroundStyle(by: .value("Seria", "przed"))
                PointMark(x: .value("Strony", point.positionInEpoch), y: .value("Loss", point.lossBefore))
                    .foregroundStyle(by: .value("Seria", "przed"))

                LineMark(
                    x: .value("Strony", point.positionInEpoch),
                    y: .value("Loss", point.lossAfter),
                    series: .value("Seria", "po")
                )
                .foregroundStyle(by: .value("Seria", "po"))
                PointMark(x: .value("Strony", point.positionInEpoch), y: .value("Loss", point.lossAfter))
                    .foregroundStyle(by: .value("Seria", "po"))
            }
            .frame(height: 280)
        }
    }

    private var currentEpochValidationLossChart: some View {
        chartCard(
            "Validation loss — bieżąca epoka",
            subtitle: "Loss na lokalnym holdoucie po każdej aktualizacji; nie jest używany do backpropagation. Poprawnie: maleje lub pozostaje nisko i stabilnie. Cel to możliwie niski loss, ale nie kosztem rosnącego validation loss — taki rozjazd oznacza overfitting."
        ) {
            Chart(diagnostics.currentEpochUpdates) { point in
                if let loss = point.validationLoss {
                    LineMark(x: .value("Strony", point.positionInEpoch), y: .value("Validation loss", loss))
                    PointMark(x: .value("Strony", point.positionInEpoch), y: .value("Validation loss", loss))
                }
            }
            .frame(height: 240)
        }
    }

    private var epochLossChart: some View {
        chartCard(
            "Loss — epoka do epoki",
            subtitle: "Średni training loss ważony liczbą stron i validation loss po około 100 stronach. Zbiorczy update jest niepodzielny, więc epoka może zakończyć się powyżej 100."
        ) {
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
        chartCard(
            "Δloss po aktualizacji",
            subtitle: "Δloss = loss przed − loss po. Poprawnie: wartości są głównie dodatnie. Na początku mogą być większe, a przy konwergencji zbliżają się do 0. Seria wartości ujemnych oznacza, że update pogarsza batch."
        ) {
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
        chartCard(
            "Ruch predykcji po backprop",
            subtitle: "Średnia i maksymalna |ΔP(advance)| na tym samym batchu przed/po update. Poprawnie: na początku wyraźnie > 0, potem stopniowo maleje przy konwergencji. Stałe ≈0 od początku oznacza brak efektywnego uczenia; duże trwałe skoki mogą oznaczać niestabilność."
        ) {
            Chart(diagnostics.updateHistory.suffix(300)) { point in
                LineMark(
                    x: .value("Aktualizacja", point.id),
                    y: .value("|Δpred|", point.meanPredictionDelta),
                    series: .value("Seria", "średnia")
                )
                .foregroundStyle(by: .value("Seria", "średnia"))
                PointMark(
                    x: .value("Aktualizacja", point.id),
                    y: .value("|Δpred|", point.meanPredictionDelta)
                )
                .foregroundStyle(by: .value("Seria", "średnia"))
                LineMark(
                    x: .value("Aktualizacja", point.id),
                    y: .value("|Δpred|", point.maxPredictionDelta),
                    series: .value("Seria", "maksimum")
                )
                .foregroundStyle(by: .value("Seria", "maksimum"))
                PointMark(
                    x: .value("Aktualizacja", point.id),
                    y: .value("|Δpred|", point.maxPredictionDelta)
                )
                .foregroundStyle(by: .value("Seria", "maksimum"))
            }
            .frame(height: 240)
        }
    }

    private var latestBackpropUpdates: some View {
        diagnosticsCard("Ostatnie kroki backprop") {
            Text("Dokładne wartości przed i po update — niezależne od skali wykresu.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(diagnostics.updateHistory.suffix(8).reversed())) { point in
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(point.id)  strony \(point.trainedPageCount ?? 1)  loss \(formatted(point.lossBefore, digits: 8)) → \(formatted(point.lossAfter, digits: 8))")
                    Text("Δloss \(signed(point.lossDelta, digits: 8))   mean |ΔP| \(formatted(point.meanPredictionDelta, digits: 8))   max \(formatted(point.maxPredictionDelta, digits: 8))")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.monospacedDigit())
            }
        }
    }

    private var currentEpochMarginChart: some View {
        chartCard(
            "Margin — bieżąca epoka",
            subtitle: "Margin = średnie P(advance) positive − negative. Poprawnie: jest dodatni i rośnie; im bliżej 1, tym silniejsza separacja. Validation margin powinien podążać za train margin, a nie pozostawać blisko 0 lub spadać."
        ) {
            Chart(diagnostics.currentEpochUpdates) { point in
                if let margin = point.trainingMargin {
                    LineMark(
                        x: .value("Strony", point.positionInEpoch),
                        y: .value("Margin", margin),
                        series: .value("Seria", "train")
                    )
                    .foregroundStyle(by: .value("Seria", "train"))
                }
                if let margin = point.validationMargin {
                    LineMark(
                        x: .value("Strony", point.positionInEpoch),
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
        chartCard(
            "Margin — epoka do epoki",
            subtitle: "Poprawnie: train i validation margin są > 0 i rosną w podobnym kierunku. Docelowo silna separacja z małą luką między seriami. Train rosnący przy validation spadającym to klasyczny sygnał overfittingu."
        ) {
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
        chartCard(
            "Separacja klas",
            subtitle: "Średnie P(advance) dla pozytywnych i negatywnych próbek. Idealny kierunek: positive → 1, negative → 0. Linie powinny się rozsuwać; zbieganie obu do ~0.5 oznacza collapse klasyfikatora."
        ) {
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
        chartCard(
            "Skład batcha",
            subtitle: "Pozytywne próbki nad osią, negatywne pod osią. Każda zbiorcza aktualizacja powinna pozostać zbalansowana 1:1; pojedyncza strona wnosi maksymalnie 12 + 12 próbek."
        ) {
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

    private var trainingTrace: some View {
        diagnosticsCard("Trace treningu") {
            Text("Ślad etapów ostatnich prób treningu. Przy błędzie ostatnia linia wskazuje etap, na którym pipeline się zatrzymał.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if state.trainingTrace.isEmpty {
                Text("Brak wpisów.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(state.trainingTrace.suffix(30).reversed().enumerated()), id: \.offset) { _, message in
                    Text(message)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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

    private func copyDiagnosticsReport() {
        let report = diagnosticsReport()
#if os(iOS)
        UIPasteboard.general.string = report
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
#endif
        didCopyDiagnostics = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCopyDiagnostics = false
        }
    }

    private func diagnosticsReport() -> String {
        var lines: [String] = []
        lines.append("Margaretka — Prayer Auto Advance diagnostics")
        lines.append("timestamp: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        lines.append("[MODEL]")
        if let metadata = state.metadata {
            lines.append("baseModelVersion: \(metadata.baseModelVersion)")
            lines.append("featureSchemaVersion: \(metadata.featureSchemaVersion)")
            lines.append("trainingSessions: \(metadata.trainingSessions)")
            lines.append("trainedTransitions: \(metadata.trainedTransitions)")
        } else {
            lines.append("metadata: unavailable")
        }
        lines.append("modelLoaded: \(state.model != nil)")
        lines.append("")
        lines.append("[PIPELINE]")
        lines.append("pipelineState: \(diagnostics.pipelineState)")
        lines.append("isTraining: \(state.isTraining)")
        lines.append("isTrainingPipelineBusy: \(state.isTrainingPipelineBusy)")
        lines.append("storedTrainingPageCount: \(state.storedTrainingPageCount)")
        lines.append("minimumPageCountForUpdate: \(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)")
        lines.append("groupedTrainingPageCount: \(state.groupedTrainingPageCount)")
        lines.append("queuedTrainingPageCount: \(state.queuedTrainingPageCount)")
        lines.append("scheduledTrainingCaptureCount: \(state.scheduledTrainingCaptureCount)")
        lines.append("pendingTrainingPages: \(state.pendingTrainingPages.count)")
        lines.append("trainingAtPrayerEndRequested: \(state.trainingAtPrayerEndRequested)")
        lines.append("trainingQueueTaskActive: \(state.trainingQueueTask != nil)")
        lines.append("groupedTrainingTaskActive: \(state.groupedTrainingTask != nil)")
        lines.append("queueProgress: \(state.trainingQueueProgressCompleted)/\(state.trainingQueueProgressTotal)")
        lines.append("lastTrainingEvent: \(state.lastTrainingEvent ?? "—")")
        lines.append("lastError: \(state.lastError ?? "—")")
        lines.append("")
        lines.append("[TRAINING METRICS]")
        lines.append("acceptedTrainingCount: \(diagnostics.acceptedTrainingCount)")
        lines.append("skippedTrainingCount: \(diagnostics.skippedTrainingCount)")
        lines.append("manualSwipeCount: \(diagnostics.manualSwipeCount)")
        lines.append("snapshotCount: \(diagnostics.snapshotCount)")
        lines.append("currentEpoch: \(diagnostics.currentEpochNumber)")
        lines.append("currentEpochPages: \(diagnostics.currentEpochSampleCount)")
        lines.append("updateHistoryCount: \(diagnostics.updateHistory.count)")
        lines.append("backpropStatus: \(diagnostics.backpropStatus)")
        lines.append("loss: \(formatted(diagnostics.logLoss, digits: 10))")
        lines.append("deltaLoss: \(signed(diagnostics.lastTrainingLossChange, digits: 10))")
        lines.append("meanDeltaPrediction: \(formatted(diagnostics.lastMeanPredictionDelta, digits: 10))")
        lines.append("maxDeltaPrediction: \(formatted(diagnostics.lastMaxPredictionDelta, digits: 10))")
        lines.append("trainMargin: \(diagnostics.predictionMargin.map { String(format: "%+.10f", $0) } ?? "—")")
        lines.append("validationLoss: \(formatted(diagnostics.currentValidationLoss, digits: 10))")
        lines.append("validationMargin: \(signed(diagnostics.currentValidationMargin, digits: 10))")
        lines.append("validationRecords: \(state.validationStore.records.count)")
        lines.append("validationSamples: \(state.validationStore.sampleCount)")
        lines.append("")
        lines.append("[LAST UPDATES]")
        if diagnostics.updateHistory.isEmpty {
            lines.append("none")
        } else {
            for point in diagnostics.updateHistory.suffix(30) {
                lines.append(
                    "#\(point.id) epoch=\(point.epoch) pages=\(point.trainedPageCount ?? 1) samples=\(point.sampleCount) P/N=\(point.positiveCount)/\(point.negativeCount) "
                        + String(format: "loss=%.10f->%.10f dLoss=%+.10f meanDP=%.10f maxDP=%.10f", point.lossBefore, point.lossAfter, point.lossDelta, point.meanPredictionDelta, point.maxPredictionDelta)
                )
            }
        }
        lines.append("")
        lines.append("[TRAINING TRACE]")
        lines.append(contentsOf: state.trainingTrace.isEmpty ? ["none"] : state.trainingTrace)
        lines.append("")
        lines.append("[RECENT EVENTS]")
        lines.append(contentsOf: diagnostics.recentMessages.isEmpty ? ["none"] : diagnostics.recentMessages)
        return lines.joined(separator: "\n")
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