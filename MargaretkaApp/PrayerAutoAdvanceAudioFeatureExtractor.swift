import Foundation

struct PrayerAutoAdvanceAudioWindow: Sendable {
    let samples: [Float]
    let sampleRate: Double
}

enum PrayerAutoAdvanceAudioFeatureExtractor {
    static let duration: TimeInterval = 7.0
    static let temporalBins = 35
    static let frequencyBands = 24
    static let featureCount = temporalBins * frequencyBands

    private static let analysisSampleRate = 8_000.0
    private static let analysisWindowSamples = 320
    private static let minimumFrequency = 80.0
    private static let maximumFrequency = 4_000.0
    private static let basis = makeBasis()

    static func features(window: PrayerAutoAdvanceAudioWindow) -> [Float] {
        guard window.sampleRate > 0, !window.samples.isEmpty else {
            return Array(repeating: 0, count: featureCount)
        }

        let desiredRawCount = Int((duration * window.sampleRate).rounded())
        let raw: [Float]
        if window.samples.count >= desiredRawCount {
            raw = Array(window.samples.suffix(desiredRawCount))
        } else {
            raw = Array(repeating: 0, count: desiredRawCount - window.samples.count) + window.samples
        }

        let rawFrameLength = max(1, Int((Double(analysisWindowSamples) / analysisSampleRate * window.sampleRate).rounded()))
        let maxStart = max(0, raw.count - rawFrameLength)
        var result: [Float] = []
        result.reserveCapacity(featureCount)

        for timeIndex in 0..<temporalBins {
            let fraction = temporalBins == 1 ? 1.0 : Double(timeIndex) / Double(temporalBins - 1)
            let start = Int((fraction * Double(maxStart)).rounded())
            let frame = resampleFrame(raw, start: start, rawLength: rawFrameLength)

            for band in 0..<frequencyBands {
                var real: Float = 0
                var imaginary: Float = 0
                let base = band * analysisWindowSamples
                for sampleIndex in 0..<analysisWindowSamples {
                    let value = frame[sampleIndex] * basis.window[sampleIndex]
                    real += value * basis.cosines[base + sampleIndex]
                    imaginary -= value * basis.sines[base + sampleIndex]
                }
                let magnitude = sqrt(real * real + imaginary * imaginary) / Float(analysisWindowSamples)
                let normalized = log1p(Double(magnitude) * 200.0) / log1p(200.0)
                result.append(Float(min(max(normalized, 0), 1)))
            }
        }
        return result
    }

    private static func resampleFrame(_ raw: [Float], start: Int, rawLength: Int) -> [Float] {
        var frame = Array(repeating: Float(0), count: analysisWindowSamples)
        guard rawLength > 1 else { return frame }
        let denominator = Double(max(analysisWindowSamples - 1, 1))
        for index in 0..<analysisWindowSamples {
            let position = Double(start) + Double(index) / denominator * Double(rawLength - 1)
            let lower = min(max(Int(position), 0), raw.count - 1)
            let upper = min(lower + 1, raw.count - 1)
            let mix = Float(position - Double(lower))
            frame[index] = raw[lower] * (1 - mix) + raw[upper] * mix
        }
        return frame
    }

    private static func makeBasis() -> Basis {
        let frequencies: [Double] = (0..<frequencyBands).map { index in
            let ratio = frequencyBands == 1 ? 0 : Double(index) / Double(frequencyBands - 1)
            return minimumFrequency * pow(maximumFrequency / minimumFrequency, ratio)
        }

        var sines = Array(repeating: Float(0), count: frequencyBands * analysisWindowSamples)
        var cosines = Array(repeating: Float(0), count: frequencyBands * analysisWindowSamples)
        var window = Array(repeating: Float(0), count: analysisWindowSamples)

        for sampleIndex in 0..<analysisWindowSamples {
            window[sampleIndex] = Float(0.5 - 0.5 * cos(2 * Double.pi * Double(sampleIndex) / Double(analysisWindowSamples - 1)))
        }
        for band in 0..<frequencyBands {
            for sampleIndex in 0..<analysisWindowSamples {
                let phase = 2 * Double.pi * frequencies[band] * Double(sampleIndex) / analysisSampleRate
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
