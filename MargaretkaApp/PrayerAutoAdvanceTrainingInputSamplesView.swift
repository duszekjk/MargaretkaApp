import SwiftUI

struct PrayerAutoAdvanceTrainingInputSamplesView: View {
    @ObservedObject private var inputDiagnostics = PrayerAutoAdvanceInputDiagnostics.shared
    @StateObject private var audioPlayer = PrayerAutoAdvanceDiagnosticAudioPlayer()
    @State private var playbackError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Próbki danych modelu")
                        .font(.headline)
                    Text("Ostatnie rzeczywiste wejścia. Audio i tekst diagnostyczny istnieją tylko w RAM i znikają po restarcie aplikacji.")
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
                Text("Brak próbek. Zostaną dodane podczas działania treningu, maksymalnie jedna co 5 sekund.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(inputDiagnostics.samples.reversed()) { sample in
                    sampleCard(sample)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                FeatureVectorInspector(title: "spoken_embedding", values: Array(sample.spokenEmbedding), globalOffset: 3)
                embeddingSource(
                    title: "page_embedding — tekst wejściowy",
                    sourceText: sample.pageEmbeddingText,
                    tokens: sample.pageTokens
                )
                FeatureVectorInspector(title: "page_embedding", values: Array(sample.pageEmbedding), globalOffset: 515)
                FeatureVectorInspector(title: "audio10", values: Array(sample.shortAudioFeatures), globalOffset: 1027)
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
                    + "input \(PrayerAutoAdvanceCoreMLModel.combinedInputSize) = 3 + 512 + 512 + "
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
