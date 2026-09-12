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
    @ObservedObject private var quality = PrayerAutoAdvanceTrainingQualityDiagnostics.shared
    @State private var didCopyDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    summary
                    groupedTrainingPipeline
                    qualityNavigation
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
            metricRow("Learning rate", String(format: "%.8f", PrayerAutoAdvanceCoreMLModel.trainingLearningRate))
            metricRow("Epoki Core ML", "\(PrayerAutoAdvanceCoreMLModel.trainingEpochCount), shuffle między epokami")
            metricRow("Epoka diagnostyczna", "\(diagnostics.currentEpochNumber), nowe strony \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)")
            metricRow("Zbiorcze aktualizacje", "\(diagnostics.updateHistory.count) zapisanych")
            metricRow("Nowe strony", "\(state.storedTrainingPageCount)/\(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)")
            metricRow("Replay", "\(state.replayTrainingPageCount)/\(PrayerAutoAdvancePendingTrainingStore.maximumReplayPageCount)")
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
                "Trening uruchamia się po 100 nowych stronach. Do batcha dochodzi do 50 losowych stron replay. "
                    + "Poprawny przebieg to: ocena modelu → 3 epoki MLUpdateTask z shuffle → weryfikacja zmiany predykcji → podmiana modelu → pomiar jakości → odświeżenie replay → usunięcie wykorzystanych nowych stron."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            metricRow("Etap", diagnostics.pipelineState)
            metricRow("Grouped pages", "\(state.groupedTrainingPageCount)")
            metricRow("Fresh stored", "\(state.storedTrainingPageCount)")
            metricRow("Replay stored", "\(state.replayTrainingPageCount)")
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

    private var qualityNavigation: some View {
        NavigationLink {
            PrayerAutoAdvanceTrainingQualityView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Jakość treningu").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                if let latest = quality.latest {
                    Text(
                        String(
                            format: "Accuracy %.1f%% • F1 %.1f%% • timing MAE %@ • świeże/replay %d/%d",
                            latest.accuracy * 100,
                            latest.f1 * 100,
                            latest.timingMAE.map { String(format: "%.3f s", $0) } ?? "—",
                            latest.freshPageCount,
                            latest.replayPageCount
                        )
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                } else {
                    Text("Po następnym udanym treningu pojawią się dodatkowe metryki i wykresy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var currentEpochLossChart: some View {
        chartCard(
            "Loss — bieżąca epoka",
            subtitle: "Cross-entropy przed i po każdej zbiorczej aktualizacji. Oś X pokazuje łączną liczbę nowych stron w epoce diagnostycznej. Replay nie nabija licznika epoki."
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
            subtitle: "Loss na lokalnym holdoucie po każdej aktualizacji; nie jest używany do backpropagation. Poprawnie: maleje lub pozostaje nisko i stabilnie."
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
            subtitle: "Średni training loss i validation loss po około 1000 nowych stronach. Replay zwiększa różnorodność batcha, ale nie przesuwa licznika epoki."
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
            subtitle: "Δloss = loss przed − loss po. Poprawnie: wartości są głównie dodatnie; przy konwergencji zbliżają się do 0."
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
            subtitle: "Średnia i maksymalna |ΔP(advance)| na tym samym batchu przed/po update. Stałe ≈0 od początku oznacza brak efektywnego uczenia."
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
            Text("Dokładne wartości przed i po update — licznik stron oznacza nowe strony; replay jest raportowany osobno w jakości treningu.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(diagnostics.updateHistory.suffix(8).reversed())) { point in
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(point.id)  nowe strony \(point.trainedPageCount ?? 1)  loss \(formatted(point.lossBefore, digits: 8)) → \(formatted(point.lossAfter, digits: 8))")
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
            subtitle: "Margin = średnie P(advance) positive − negative. Poprawnie: jest dodatni i rośnie."
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
            subtitle: "Train i validation margin powinny rosnąć w podobnym kierunku. Rozjazd jest sygnałem overfittingu."
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
            subtitle: "Średnie P(advance) dla pozytywnych i negatywnych próbek. Idealny kierunek: positive → 1, negative → 0."
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
            subtitle: "Pozytywne próbki nad osią, negatywne pod osią. Batch powinien pozostać zbalansowany 1:1."
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
        diagnosticsCard("Timing runtime") {
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
        lines.append("trainingEpochs: \(PrayerAutoAdvanceCoreMLModel.trainingEpochCount)")
        lines.append("trainingLearningRate: \(PrayerAutoAdvanceCoreMLModel.trainingLearningRate)")
        lines.append("shuffleBetweenEpochs: true")
        lines.append("")
        lines.append("[PIPELINE]")
        lines.append("pipelineState: \(diagnostics.pipelineState)")
        lines.append("isTraining: \(state.isTraining)")
        lines.append("isTrainingPipelineBusy: \(state.isTrainingPipelineBusy)")
        lines.append("freshTrainingPageCount: \(state.storedTrainingPageCount)")
        lines.append("minimumFreshPageCountForUpdate: \(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)")
        lines.append("replayTrainingPageCount: \(state.replayTrainingPageCount)")
        lines.append("maximumReplayPageCount: \(PrayerAutoAdvancePendingTrainingStore.maximumReplayPageCount)")
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
        lines.append("currentEpochFreshPages: \(diagnostics.currentEpochSampleCount)/\(PrayerAutoAdvanceTrainingDiagnostics.epochSize)")
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
        if let metric = quality.latest {
            lines.append("")
            lines.append("[QUALITY — LAST GROUPED UPDATE]")
            lines.append("freshPages: \(metric.freshPageCount)")
            lines.append("replayPages: \(metric.replayPageCount)")
            lines.append("samples: \(metric.sampleCount)")
            lines.append(String(format: "accuracy: %.8f", metric.accuracy))
            lines.append(String(format: "balancedAccuracy: %.8f", metric.balancedAccuracy))
            lines.append(String(format: "precision: %.8f", metric.precision))
            lines.append(String(format: "recall: %.8f", metric.recall))
            lines.append(String(format: "specificity: %.8f", metric.specificity))
            lines.append(String(format: "f1: %.8f", metric.f1))
            lines.append(String(format: "brierScore: %.8f", metric.brierScore))
            lines.append(String(format: "qualityLogLoss: %.8f", metric.logLoss))
            lines.append("timingPages: \(metric.timingPageCount)")
            lines.append("timingMAE: \(metric.timingMAE.map { String(format: "%.6f", $0) } ?? "—")")
            lines.append("timingMedianAE: \(metric.timingMedianAbsoluteError.map { String(format: "%.6f", $0) } ?? "—")")
            lines.append("timingBias: \(metric.timingBias.map { String(format: "%+.6f", $0) } ?? "—")")
            lines.append("timingHit025: \(metric.timingHitQuarterSecond.map { String(format: "%.6f", $0) } ?? "—")")
            lines.append("timingHit05: \(metric.timingHitHalfSecond.map { String(format: "%.6f", $0) } ?? "—")")
            lines.append("timingHit10: \(metric.timingHitOneSecond.map { String(format: "%.6f", $0) } ?? "—")")
        }
        lines.append("")
        lines.append("[LAST UPDATES]")
        if diagnostics.updateHistory.isEmpty {
            lines.append("none")
        } else {
            for point in diagnostics.updateHistory.suffix(30) {
                lines.append(
                    "#\(point.id) epoch=\(point.epoch) freshPages=\(point.trainedPageCount ?? 1) samples=\(point.sampleCount) P/N=\(point.positiveCount)/\(point.negativeCount) "
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
