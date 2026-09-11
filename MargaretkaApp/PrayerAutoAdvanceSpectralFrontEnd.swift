import Accelerate
import Foundation

struct PrayerAutoAdvanceSpectralHistory: Sendable {
    let firstFrameStartSampleIndex: Int
    let frameCount: Int
    let bands: [Float]
    let sampleRate: Double

    func shortFeatures(endingAt endSampleIndex: Int) -> [Float] {
        PrayerAutoAdvanceSpectralFrontEnd.temporalFeatures(
            history: self,
            endingAt: endSampleIndex,
            duration: PrayerAutoAdvanceAudioFeatureExtractor.duration,
            temporalBins: PrayerAutoAdvanceAudioFeatureExtractor.temporalBins,
            frequencyBands: PrayerAutoAdvanceAudioFeatureExtractor.frequencyBands
        )
    }

    func longFeatures(endingAt endSampleIndex: Int) -> [Float] {
        PrayerAutoAdvanceSpectralFrontEnd.temporalFeatures(
            history: self,
            endingAt: endSampleIndex,
            duration: PrayerAutoAdvanceLongAudioFeatureExtractor.duration,
            temporalBins: PrayerAutoAdvanceLongAudioFeatureExtractor.temporalBins,
            frequencyBands: PrayerAutoAdvanceLongAudioFeatureExtractor.frequencyBands
        )
    }
}

struct PrayerAutoAdvanceAudioFeaturePair: Sendable {
    let short: [Float]
    let long: [Float]
}

enum PrayerAutoAdvanceSpectralFrontEnd {
    static let sampleRate = 16_000.0
    static let analysisWindowSamples = 640       // 40 ms
    static let hopSamples = 320                  // 20 ms fixed grid
    static let sharedFrequencyBands = 48
    static let minimumFrequency = 80.0
    static let maximumFrequency = 8_000.0

    private static let basis = makeBasis()
    private static let normalizationDenominator = log1p(200.0)

    static func analyze(samples: [Float]) -> PrayerAutoAdvanceSpectralHistory {
        guard samples.count >= analysisWindowSamples else {
            return PrayerAutoAdvanceSpectralHistory(
                firstFrameStartSampleIndex: 0,
                frameCount: 0,
                bands: [],
                sampleRate: sampleRate
            )
        }

        let frameCount = (samples.count - analysisWindowSamples) / hopSamples + 1
        var allBands: [Float] = []
        allBands.reserveCapacity(frameCount * sharedFrequencyBands)

        var start = 0
        for _ in 0..<frameCount {
            allBands.append(contentsOf: spectralBands(samples: samples, start: start))
            start += hopSamples
        }

        return PrayerAutoAdvanceSpectralHistory(
            firstFrameStartSampleIndex: 0,
            frameCount: frameCount,
            bands: allBands,
            sampleRate: sampleRate
        )
    }

    static func spectralBands(samples: [Float], start: Int) -> [Float] {
        guard start >= 0,
              start + analysisWindowSamples <= samples.count else {
            return Array(repeating: 0, count: sharedFrequencyBands)
        }

        var windowed = Array(repeating: Float(0), count: analysisWindowSamples)
        samples.withUnsafeBufferPointer { input in
            basis.window.withUnsafeBufferPointer { window in
                windowed.withUnsafeMutableBufferPointer { output in
                    vDSP_vmul(
                        input.baseAddress!.advanced(by: start), 1,
                        window.baseAddress!, 1,
                        output.baseAddress!, 1,
                        vDSP_Length(analysisWindowSamples)
                    )
                }
            }
        }

        var result = Array(repeating: Float(0), count: sharedFrequencyBands)
        windowed.withUnsafeBufferPointer { values in
            basis.cosines.withUnsafeBufferPointer { cosines in
                basis.sines.withUnsafeBufferPointer { sines in
                    for band in 0..<sharedFrequencyBands {
                        let offset = band * analysisWindowSamples
                        var real: Float = 0
                        var imaginary: Float = 0
                        vDSP_dotpr(
                            values.baseAddress!, 1,
                            cosines.baseAddress!.advanced(by: offset), 1,
                            &real,
                            vDSP_Length(analysisWindowSamples)
                        )
                        vDSP_dotpr(
                            values.baseAddress!, 1,
                            sines.baseAddress!.advanced(by: offset), 1,
                            &imaginary,
                            vDSP_Length(analysisWindowSamples)
                        )
                        let magnitude = hypot(real, imaginary) / Float(analysisWindowSamples)
                        let normalized = log1p(Double(magnitude) * 200.0) / normalizationDenominator
                        result[band] = Float(min(max(normalized, 0), 1))
                    }
                }
            }
        }
        return result
    }

    static func temporalFeatures(
        history: PrayerAutoAdvanceSpectralHistory,
        endingAt endSampleIndex: Int,
        duration: TimeInterval,
        temporalBins: Int,
        frequencyBands: Int
    ) -> [Float] {
        guard temporalBins > 0, frequencyBands > 0 else { return [] }
        let outputCount = temporalBins * frequencyBands
        guard history.sampleRate == sampleRate,
              history.frameCount > 0,
              history.bands.count >= history.frameCount * sharedFrequencyBands else {
            return Array(repeating: 0, count: outputCount)
        }

        let durationSamples = Int((duration * sampleRate).rounded())
        let maxFrameStartOffset = max(0, durationSamples - analysisWindowSamples)
        let windowStart = endSampleIndex - durationSamples
        var output: [Float] = []
        output.reserveCapacity(outputCount)

        for timeIndex in 0..<temporalBins {
            let fraction = temporalBins == 1
                ? 1.0
                : Double(timeIndex) / Double(temporalBins - 1)
            let desiredStart = windowStart + Int((fraction * Double(maxFrameStartOffset)).rounded())

            guard desiredStart >= 0 else {
                appendZeros(count: frequencyBands, to: &output)
                continue
            }

            let relative = Double(desiredStart - history.firstFrameStartSampleIndex) / Double(hopSamples)
            let frameIndex = Int(relative.rounded())
            guard frameIndex >= 0, frameIndex < history.frameCount else {
                appendZeros(count: frequencyBands, to: &output)
                continue
            }

            let actualStart = history.firstFrameStartSampleIndex + frameIndex * hopSamples
            guard abs(actualStart - desiredStart) <= hopSamples else {
                appendZeros(count: frequencyBands, to: &output)
                continue
            }

            appendFrame(
                history: history,
                frameIndex: frameIndex,
                frequencyBands: frequencyBands,
                to: &output
            )
        }
        return output
    }

    private static func appendFrame(
        history: PrayerAutoAdvanceSpectralHistory,
        frameIndex: Int,
        frequencyBands: Int,
        to output: inout [Float]
    ) {
        let base = frameIndex * sharedFrequencyBands
        if frequencyBands == sharedFrequencyBands {
            output.append(contentsOf: history.bands[base..<(base + sharedFrequencyBands)])
            return
        }

        guard frequencyBands > 0 else { return }
        if frequencyBands == 1 {
            output.append(history.bands[base + sharedFrequencyBands / 2])
            return
        }

        let scale = Double(sharedFrequencyBands - 1) / Double(frequencyBands - 1)
        for index in 0..<frequencyBands {
            let position = Double(index) * scale
            let lower = Int(position.rounded(.down))
            let upper = min(lower + 1, sharedFrequencyBands - 1)
            let mix = Float(position - Double(lower))
            let low = history.bands[base + lower]
            let high = history.bands[base + upper]
            output.append(low * (1 - mix) + high * mix)
        }
    }

    private static func appendZeros(count: Int, to output: inout [Float]) {
        output.append(contentsOf: repeatElement(Float(0), count: count))
    }

    private static func makeBasis() -> Basis {
        let frequencies: [Double] = (0..<sharedFrequencyBands).map { index in
            let ratio = sharedFrequencyBands == 1
                ? 0
                : Double(index) / Double(sharedFrequencyBands - 1)
            return minimumFrequency * pow(maximumFrequency / minimumFrequency, ratio)
        }

        var sines = Array(repeating: Float(0), count: sharedFrequencyBands * analysisWindowSamples)
        var cosines = Array(repeating: Float(0), count: sharedFrequencyBands * analysisWindowSamples)
        var window = Array(repeating: Float(0), count: analysisWindowSamples)

        for sampleIndex in 0..<analysisWindowSamples {
            window[sampleIndex] = Float(
                0.5 - 0.5 * cos(
                    2 * Double.pi * Double(sampleIndex) / Double(analysisWindowSamples - 1)
                )
            )
        }

        for band in 0..<sharedFrequencyBands {
            for sampleIndex in 0..<analysisWindowSamples {
                let phase = 2 * Double.pi * frequencies[band] * Double(sampleIndex) / sampleRate
                let offset = band * analysisWindowSamples + sampleIndex
                sines[offset] = Float(sin(phase))
                cosines[offset] = Float(cos(phase))
            }
        }
        return Basis(sines: sines, cosines: cosines, window: window)
    }

    private struct Basis {
        let sines: [Float]
        let cosines: [Float]
        let window: [Float]
    }
}

/// Incremental V12 cache for automatic prediction. New PCM is ingested in 0.5 s
/// bursts; only unseen fixed-grid frames are transformed. The cache returns only
/// the final 6240 audio features, never a copied 60 s spectral history.
final class PrayerAutoAdvanceStreamingSpectralCache: @unchecked Sendable {
    private let lock = NSLock()
    private var pcm: [Float] = []
    private var pcmStartSampleIndex = 0
    private var nextFrameStartSampleIndex = 0
    private var nextExpectedSampleIndex = 0
    private var firstFrameStartSampleIndex = 0
    private var frameCount = 0
    private var bands: [Float] = []

    private let maximumFrameCount = Int(
        ceil((PrayerAutoAdvanceLongAudioFeatureExtractor.duration + 1.0)
            * PrayerAutoAdvanceSpectralFrontEnd.sampleRate
            / Double(PrayerAutoAdvanceSpectralFrontEnd.hopSamples))
    )

    func reset() {
        lock.lock()
        pcm.removeAll(keepingCapacity: true)
        pcmStartSampleIndex = 0
        nextFrameStartSampleIndex = 0
        nextExpectedSampleIndex = 0
        firstFrameStartSampleIndex = 0
        frameCount = 0
        bands.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func ingest(samples: [Float], startingAt startSampleIndex: Int) {
        guard !samples.isEmpty else { return }
        lock.lock()
        if startSampleIndex != nextExpectedSampleIndex {
            pcm.removeAll(keepingCapacity: true)
            bands.removeAll(keepingCapacity: true)
            frameCount = 0
            pcmStartSampleIndex = startSampleIndex
            nextFrameStartSampleIndex = startSampleIndex
            firstFrameStartSampleIndex = startSampleIndex
        }
        pcm.append(contentsOf: samples)
        nextExpectedSampleIndex = startSampleIndex + samples.count

        let availableEnd = pcmStartSampleIndex + pcm.count
        while nextFrameStartSampleIndex + PrayerAutoAdvanceSpectralFrontEnd.analysisWindowSamples <= availableEnd {
            let localStart = nextFrameStartSampleIndex - pcmStartSampleIndex
            if frameCount == 0 {
                firstFrameStartSampleIndex = nextFrameStartSampleIndex
            }
            bands.append(
                contentsOf: PrayerAutoAdvanceSpectralFrontEnd.spectralBands(
                    samples: pcm,
                    start: localStart
                )
            )
            frameCount += 1
            nextFrameStartSampleIndex += PrayerAutoAdvanceSpectralFrontEnd.hopSamples
        }

        if frameCount > maximumFrameCount {
            let dropFrames = frameCount - maximumFrameCount
            bands.removeFirst(dropFrames * PrayerAutoAdvanceSpectralFrontEnd.sharedFrequencyBands)
            firstFrameStartSampleIndex += dropFrames * PrayerAutoAdvanceSpectralFrontEnd.hopSamples
            frameCount = maximumFrameCount
        }

        let discardCount = min(
            max(0, nextFrameStartSampleIndex - pcmStartSampleIndex),
            pcm.count
        )
        if discardCount > 0 {
            pcm.removeFirst(discardCount)
            pcmStartSampleIndex += discardCount
        }
        lock.unlock()
    }

    func features(endingAt endSampleIndex: Int) -> PrayerAutoAdvanceAudioFeaturePair {
        lock.lock()
        let history = PrayerAutoAdvanceSpectralHistory(
            firstFrameStartSampleIndex: firstFrameStartSampleIndex,
            frameCount: frameCount,
            bands: bands,
            sampleRate: PrayerAutoAdvanceSpectralFrontEnd.sampleRate
        )
        let short = history.shortFeatures(endingAt: endSampleIndex)
        let long = history.longFeatures(endingAt: endSampleIndex)
        lock.unlock()
        return PrayerAutoAdvanceAudioFeaturePair(short: short, long: long)
    }
}
