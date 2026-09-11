import Accelerate
import Foundation

struct PrayerAutoAdvanceSpectralFrame: Sendable {
    let startSampleIndex: Int
    let bands: [Float]
}

struct PrayerAutoAdvanceSpectralHistory: Sendable {
    let frames: [PrayerAutoAdvanceSpectralFrame]
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
            return PrayerAutoAdvanceSpectralHistory(frames: [], sampleRate: sampleRate)
        }

        var frames: [PrayerAutoAdvanceSpectralFrame] = []
        frames.reserveCapacity(max(0, (samples.count - analysisWindowSamples) / hopSamples + 1))

        var start = 0
        while start + analysisWindowSamples <= samples.count {
            let frame = Array(samples[start..<(start + analysisWindowSamples)])
            frames.append(
                PrayerAutoAdvanceSpectralFrame(
                    startSampleIndex: start,
                    bands: spectralBands(frame)
                )
            )
            start += hopSamples
        }

        return PrayerAutoAdvanceSpectralHistory(frames: frames, sampleRate: sampleRate)
    }

    static func spectralBands(_ frame: [Float]) -> [Float] {
        guard frame.count == analysisWindowSamples else {
            return Array(repeating: 0, count: sharedFrequencyBands)
        }

        var windowed = Array(repeating: Float(0), count: analysisWindowSamples)
        frame.withUnsafeBufferPointer { input in
            basis.window.withUnsafeBufferPointer { window in
                vDSP_vmul(
                    input.baseAddress!, 1,
                    window.baseAddress!, 1,
                    &windowed, 1,
                    vDSP_Length(analysisWindowSamples)
                )
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
              let firstFrame = history.frames.first else {
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
                output.append(contentsOf: repeatElement(Float(0), count: frequencyBands))
                continue
            }

            let relative = Double(desiredStart - firstFrame.startSampleIndex) / Double(hopSamples)
            let frameIndex = Int(relative.rounded())
            guard history.frames.indices.contains(frameIndex) else {
                output.append(contentsOf: repeatElement(Float(0), count: frequencyBands))
                continue
            }

            let frame = history.frames[frameIndex]
            if abs(frame.startSampleIndex - desiredStart) > hopSamples {
                output.append(contentsOf: repeatElement(Float(0), count: frequencyBands))
                continue
            }

            if frequencyBands == sharedFrequencyBands {
                output.append(contentsOf: frame.bands)
            } else {
                output.append(contentsOf: resampleBands(frame.bands, count: frequencyBands))
            }
        }
        return output
    }

    private static func resampleBands(_ source: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !source.isEmpty else { return Array(repeating: 0, count: count) }
        if count == source.count { return source }
        if count == 1 { return [source[source.count / 2]] }

        var result = Array(repeating: Float(0), count: count)
        let scale = Double(source.count - 1) / Double(count - 1)
        for index in 0..<count {
            let position = Double(index) * scale
            let lower = Int(position.rounded(.down))
            let upper = min(lower + 1, source.count - 1)
            let mix = Float(position - Double(lower))
            result[index] = source[lower] * (1 - mix) + source[upper] * mix
        }
        return result
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
/// bursts; only previously unseen 20 ms grid frames are transformed. The cache
/// retains just over 60 s of spectral history, not overlapping raw audio windows.
final class PrayerAutoAdvanceStreamingSpectralCache: @unchecked Sendable {
    private let lock = NSLock()
    private var pcm: [Float] = []
    private var pcmStartSampleIndex = 0
    private var nextFrameStartSampleIndex = 0
    private var nextExpectedSampleIndex = 0
    private var frames: [PrayerAutoAdvanceSpectralFrame] = []

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
        frames.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func ingest(samples: [Float], startingAt startSampleIndex: Int) {
        guard !samples.isEmpty else { return }
        lock.lock()
        if startSampleIndex != nextExpectedSampleIndex {
            pcm.removeAll(keepingCapacity: true)
            frames.removeAll(keepingCapacity: true)
            pcmStartSampleIndex = startSampleIndex
            nextFrameStartSampleIndex = startSampleIndex
        }
        pcm.append(contentsOf: samples)
        nextExpectedSampleIndex = startSampleIndex + samples.count

        let availableEnd = pcmStartSampleIndex + pcm.count
        while nextFrameStartSampleIndex + PrayerAutoAdvanceSpectralFrontEnd.analysisWindowSamples <= availableEnd {
            let localStart = nextFrameStartSampleIndex - pcmStartSampleIndex
            let localEnd = localStart + PrayerAutoAdvanceSpectralFrontEnd.analysisWindowSamples
            let frame = Array(pcm[localStart..<localEnd])
            frames.append(
                PrayerAutoAdvanceSpectralFrame(
                    startSampleIndex: nextFrameStartSampleIndex,
                    bands: PrayerAutoAdvanceSpectralFrontEnd.spectralBands(frame)
                )
            )
            nextFrameStartSampleIndex += PrayerAutoAdvanceSpectralFrontEnd.hopSamples
        }

        if frames.count > maximumFrameCount {
            frames.removeFirst(frames.count - maximumFrameCount)
        }

        let discardBefore = max(pcmStartSampleIndex, nextFrameStartSampleIndex)
        let discardCount = min(max(0, discardBefore - pcmStartSampleIndex), pcm.count)
        if discardCount > 0 {
            pcm.removeFirst(discardCount)
            pcmStartSampleIndex += discardCount
        }
        lock.unlock()
    }

    func history() -> PrayerAutoAdvanceSpectralHistory {
        lock.lock()
        let snapshot = frames
        lock.unlock()
        return PrayerAutoAdvanceSpectralHistory(
            frames: snapshot,
            sampleRate: PrayerAutoAdvanceSpectralFrontEnd.sampleRate
        )
    }
}
