import SwiftUI

struct PrayerAutoAdvanceTrainingInputSamplesView: View {
    @ObservedObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @ObservedObject private var inputDiagnostics = PrayerAutoAdvanceInputDiagnostics.shared
    @StateObject private var audioPlayer = PrayerAutoAdvanceDiagnosticAudioPlayer()
    @State private var playbackError: String?
    @State private var storedFreshPages: [PrayerAutoAdvancePendingTrainingPage] = []
    @State private var storedReplayPages: [PrayerAutoAdvancePendingTrainingPage] = []
    @State private var storedDataError: String?
    @State private var isLoadingStoredData = false
    @State private var visibleStoredPageCount = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            persistedTrainingDataSection
            Divider()
            liveRAMSamplesSection
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: "\(state.storedTrainingPageCount)-\(state.replayTrainingPageCount)") {
            await loadStoredTrainingData()
        }
    }

    private var persistedTrainingDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Zapisane dane treningowe")
                        .font(.headline)
                    Text(
                        "Trwałe strony używane przez grouped training. Fresh czekają na następny update, replay pozostaje historyczną pulą stabilizującą kolejne treningi."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Odśwież") {
                    Task { await loadStoredTrainingData() }
                }
                .font(.caption)
            }

            HStack(spacing: 12) {
                Text("fresh \(storedFreshPages.count)/\(PrayerAutoAdvancePendingTrainingStore.minimumPageCountForUpdate)")
                Text("replay \(storedReplayPages.count)/\(PrayerAutoAdvancePendingTrainingStore.maximumReplayPageCount)")
                Text("razem \(storedPageEntries.count)")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            Text("Te rekordy są odczytywane z dysku i pozostają dostępne po restarcie. Zawierają dokładne cechy wejściowe, etykietę i czas względem ręcznego przewinięcia. PCM i pełny tekst diagnostyczny nie są utrwalane.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLoadingStoredData {
                ProgressView("Wczytywanie zapisanych stron…")
                    .font(.caption)
            } else if let storedDataError {
                Text("Błąd odczytu: \(storedDataError)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
            } else if storedPageEntries.isEmpty {
                Text("Brak zapisanych stron fresh/replay.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(storedPageEntries.prefix(visibleStoredPageCount))) { entry in
                    storedPageCard(entry)
                }

                if visibleStoredPageCount < storedPageEntries.count {
                    Button("Pokaż więcej (+10)") {
                        visibleStoredPageCount = min(
                            visibleStoredPageCount + 10,
                            storedPageEntries.count
                        )
                    }
                    .buttonStyle(.bordered)
                }
                if visibleStoredPageCount > 6 {
                    Button("Pokaż mniej") {
                        visibleStoredPageCount = 6
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var liveRAMSamplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Bieżące próbki RAM — audio i tekst")
                        .font(.headline)
                    Text("Ostatnie rzeczywiste wejścia z PCM i tekstem diagnostycznym. Ta część istnieje tylko w RAM i znika po restarcie aplikacji.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Wyczyść") {
                    audioPlayer.stop()
                    inputDiagnostics.clear()
                }
                .font(.caption)
            }

            if let playbackError {
                Text(playbackError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if inputDiagnostics.samples.isEmpty {
                Text("Brak bieżących próbek RAM. Zapisane dane fresh/replay powyżej są niezależne od tego podglądu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(inputDiagnostics.samples.reversed()) { sample in
                    sampleCard(sample)
                }
            }
        }
    }

    private var storedPageEntries: [StoredPageEntry] {
        let fresh = storedFreshPages.reversed().map {
            StoredPageEntry(source: "fresh", page: $0)
        }
        let replay = storedReplayPages.shuffled().map {
            StoredPageEntry(source: "replay", page: $0)
        }
        return Array(fresh) + replay
    }

    private func storedPageCard(_ entry: StoredPageEntry) -> some View {
        let positives = entry.page.samples.filter { $0.label == 1 }.count
        let negatives = entry.page.samples.count - positives
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text("Przykładowe próbki z tej strony (maks. 8)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(entry.page.samples.prefix(8).enumerated()), id: \.offset) { index, sample in
                    storedSampleRow(index: index, sample: sample)
                }

                if entry.page.samples.count > 8 {
                    Text("… oraz \(entry.page.samples.count - 8) dalszych próbek w pliku treningowym")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.source.uppercased())
                        .font(.caption.bold())
                    Spacer()
                    Text(entry.page.createdAt.formatted(date: .numeric, time: .standard))
                        .font(.caption.monospacedDigit())
                }
                Text(entry.page.pageID)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                Text("próbki \(entry.page.samples.count) · P/N \(positives)/\(negatives)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func storedSampleRow(index: Int, sample: PrayerAutoAdvanceLabeledSample) -> some View {
        let scalars = Array(sample.features.prefix(PrayerAutoAdvanceFeatureExtractor.progressFeatureCount))
        let relativeTime = sample.relativeTimeToAdvance.map { String(format: "%+.3f s", $0) } ?? "—"
        let shortStart = PrayerAutoAdvanceFeatureExtractor.progressFeatureCount
            + 2 * PrayerAutoAdvanceFeatureExtractor.textEmbeddingSize
        let shortEnd = min(
            shortStart + PrayerAutoAdvanceAudioFeatureExtractor.featureCount,
            sample.features.count
        )
        let shortAudio = shortStart < shortEnd ? Array(sample.features[shortStart..<shortEnd]) : []

        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("#\(index)  label=\(sample.label == 1 ? "advance" : "stay")")
                Spacer()
                Text("t=\(relativeTime)")
            }
            .font(.caption.monospaced())

            Text(
                "scalars=" + scalars.map { String(format: "%.4f", $0) }.joined(separator: ", ")
                    + String(format: " · audio10 rms=%.5f · audio60 rms=%.5f", rms(shortAudio), rms(sample.longAudioFeatures))
            )
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        .padding(.vertical, 3)
    }

    private func loadStoredTrainingData() async {
        isLoadingStoredData = true
        storedDataError = nil
        let freshDirectory = state.pendingTrainingDirectory
        let replayDirectory = state.replayTrainingDirectory

        do {
            let result = try await Task.detached(priority: .utility) {
                let fresh = try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: freshDirectory)
                let replay = try PrayerAutoAdvancePendingTrainingStore.loadSnapshot(from: replayDirectory)
                return (fresh.pages, replay.pages)
            }.value
            storedFreshPages = result.0
            storedReplayPages = result.1
            visibleStoredPageCount = min(max(visibleStoredPageCount, 6), max(6, storedPageEntries.count))
        } catch {
            storedDataError = error.localizedDescription
        }
        isLoadingStoredData = false
    }

    private func sampleCard(_ sample: PrayerAutoAdvanceDiagnosticInputSample) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    playbackButton(sample: sample, duration: 10)
                    playbackButton(sample: sample, duration: 60)

                    if audioPlayer.isPlaying {
                        Button("Stop") { audioPlayer.stop() }
                            .buttonStyle(.bordered)
                    }
                }

                Text("Odsłuch: mono Float32, \(Int(sample.sampleRate)) Hz, dokładnie z bufora używanego do ekstrakcji cech. Model nie dostaje PCM bezpośrednio — dostaje poniższe cechy widmowe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                scalarTable(sample)
                embeddingSource(
                    title: "spoken_embedding — tekst wejściowy",
                    sourceText: sample.spokenEmbeddingText,
                    tokens: sample.spokenTokens
                )
                FeatureVectorInspector(
                    title: "spoken_embedding",
                    values: Array(sample.spokenEmbedding),
                    globalOffset: PrayerAutoAdvanceFeatureExtractor.progressFeatureCount
                )
                embeddingSource(
                    title: "page_embedding — tekst wejściowy",
                    sourceText: sample.pageEmbeddingText,
                    tokens: sample.pageTokens
                )
                FeatureVectorInspector(
                    title: "page_embedding",
                    values: Array(sample.pageEmbedding),
                    globalOffset: PrayerAutoAdvanceFeatureExtractor.progressFeatureCount
                        + PrayerAutoAdvanceFeatureExtractor.textEmbeddingSize
                )
                FeatureVectorInspector(
                    title: "audio10",
                    values: Array(sample.shortAudioFeatures),
                    globalOffset: PrayerAutoAdvanceFeatureExtractor.progressFeatureCount
                        + 2 * PrayerAutoAdvanceFeatureExtractor.textEmbeddingSize
                )
                FeatureVectorInspector(
                    title: "audio60",
                    values: sample.longAudioFeatures,
                    globalOffset: PrayerAutoAdvanceCoreMLModel.inputSize
                )
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sample.date.formatted(date: .omitted, time: .standard))
                        .monospacedDigit()
                    Spacer()
                    Text(String(format: "pred %.5f", sample.prediction))
                        .monospacedDigit()
                }
                Text(sample.pageID)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Text(
                    "PCM \(String(format: "%.1f", Double(sample.pcmSamples.count) / sample.sampleRate)) s · "
                    + "input \(PrayerAutoAdvanceCoreMLModel.combinedInputSize) = "
                    + "\(PrayerAutoAdvanceFeatureExtractor.progressFeatureCount) + 512 + 512 + "
                    + "\(PrayerAutoAdvanceAudioFeatureExtractor.featureCount) + \(PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount)"
                )
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func playbackButton(sample: PrayerAutoAdvanceDiagnosticInputSample, duration: TimeInterval) -> some View {
        let active = audioPlayer.isPlaying(sampleID: sample.id, duration: duration)
        Button {
            play(sample: sample, duration: duration)
        } label: {
            HStack(spacing: 6) {
                if active {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "play.fill")
                }
                Text("\(Int(duration)) s")
            }
        }
        .buttonStyle(.bordered)
        .tint(active ? .orange : nil)
    }

    private func embeddingSource(title: String, sourceText: String, tokens: [String]) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text(sourceText.isEmpty ? "(pusty tekst)" : sourceText)
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                if tokens.isEmpty {
                    Text("Brak tokenów")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("[\(index)]")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                            Text(token)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(.top, 5)
        } label: {
            Text("\(title) · tokeny [\(tokens.count)]")
                .font(.subheadline.bold())
        }
    }

    private func scalarTable(_ sample: PrayerAutoAdvanceDiagnosticInputSample) -> some View {
        let values = Array(sample.scalars)
        return VStack(alignment: .leading, spacing: 4) {
            Text("scalars")
                .font(.subheadline.bold())
            scalarRow("[0] elapsed / 120", value: values.indices.contains(0) ? values[0] : 0)
            scalarRow("[1] spoken words / 120", value: values.indices.contains(1) ? values[1] : 0)
            scalarRow("[2] page words / 300", value: values.indices.contains(2) ? values[2] : 0)
            scalarRow("[3] last speech end / 300", value: values.indices.contains(3) ? values[3] : 0)
        }
    }

    private func scalarRow(_ name: String, value: Float) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(String(format: "%.8f", value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func play(sample: PrayerAutoAdvanceDiagnosticInputSample, duration: TimeInterval) {
        do {
            try audioPlayer.play(
                sampleID: sample.id,
                duration: duration,
                samples: sample.pcm(duration: duration),
                sampleRate: sample.sampleRate
            )
            playbackError = nil
        } catch {
            playbackError = error.localizedDescription
        }
    }

    private func rms(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return sqrt(values.reduce(Float.zero) { $0 + $1 * $1 } / Float(values.count))
    }

    private struct StoredPageEntry: Identifiable {
        let source: String
        let page: PrayerAutoAdvancePendingTrainingPage

        var id: String { "\(source)-\(page.id.uuidString)" }
    }
}

private struct FeatureVectorInspector: View {
    let title: String
    let values: [Float]
    let globalOffset: Int

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 12) {
                    Text("min \(format(values.min() ?? 0))")
                    Text("max \(format(values.max() ?? 0))")
                    Text("mean \(format(mean))")
                    Text("rms \(format(rms))")
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

                ForEach(Array(chunks.enumerated()), id: \.offset) { chunkIndex, chunk in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(globalOffset + chunkIndex * 16)…\(globalOffset + chunkIndex * 16 + chunk.count - 1)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Text(chunk.map(format).joined(separator: "  "))
                            .font(.system(size: 8, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, 5)
        } label: {
            Text("\(title) [\(values.count)]")
                .font(.subheadline.bold())
        }
    }

    private var chunks: [[Float]] {
        stride(from: 0, to: values.count, by: 16).map { start in
            Array(values[start..<min(start + 16, values.count)])
        }
    }

    private var mean: Float {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }

    private var rms: Float {
        guard !values.isEmpty else { return 0 }
        return sqrt(values.reduce(Float.zero) { $0 + $1 * $1 } / Float(values.count))
    }

    private func format(_ value: Float) -> String {
        String(format: "%.5f", value)
    }
}
