import AVFoundation
import Foundation
internal import Combine

struct PrayerAutoAdvanceDiagnosticInputSample: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let pageID: String
    let prediction: Float
    let features: [Float]
    let longAudioFeatures: [Float]
    let pcmSamples: [Float]
    let sampleRate: Double

    var scalars: ArraySlice<Float> { features.prefix(3) }
    var spokenEmbedding: ArraySlice<Float> { features[3..<min(515, features.count)] }
    var pageEmbedding: ArraySlice<Float> { features[min(515, features.count)..<min(1027, features.count)] }
    var shortAudioFeatures: ArraySlice<Float> { features[min(1027, features.count)..<features.count] }

    func pcm(duration: TimeInterval) -> [Float] {
        let count = min(pcmSamples.count, max(0, Int((duration * sampleRate).rounded())))
        return Array(pcmSamples.suffix(count))
    }
}

@MainActor
final class PrayerAutoAdvanceInputDiagnostics: ObservableObject {
    static let shared = PrayerAutoAdvanceInputDiagnostics()
    private static let maximumSamples = 5
    private static let captureInterval: TimeInterval = 5

    @Published private(set) var samples: [PrayerAutoAdvanceDiagnosticInputSample] = []
    private var lastCaptureAt = Date.distantPast

    func record(
        pageID: String,
        prediction: Float,
        features: [Float],
        longAudioFeatures: [Float],
        audioWindow: PrayerAutoAdvanceAudioWindow,
        at date: Date
    ) {
        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey),
              date.timeIntervalSince(lastCaptureAt) >= Self.captureInterval else { return }
        lastCaptureAt = date

        samples.append(
            PrayerAutoAdvanceDiagnosticInputSample(
                id: UUID(),
                date: date,
                pageID: pageID,
                prediction: prediction,
                features: features,
                longAudioFeatures: longAudioFeatures,
                pcmSamples: audioWindow.samples,
                sampleRate: audioWindow.sampleRate
            )
        )
        if samples.count > Self.maximumSamples {
            samples.removeFirst(samples.count - Self.maximumSamples)
        }
    }

    func clear() {
        samples.removeAll(keepingCapacity: false)
        lastCaptureAt = .distantPast
    }
}

@MainActor
final class PrayerAutoAdvanceDiagnosticAudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    init() {
        engine.attach(player)
    }

    deinit {
        player.stop()
        engine.stop()
    }

    func play(samples: [Float], sampleRate: Double) throws {
        stop()
        guard !samples.isEmpty, sampleRate > 0 else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ),
        let channel = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        isPlaying = true
        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        player.play()
    }

    func stop() {
        player.stop()
        if engine.isRunning { engine.stop() }
        isPlaying = false
    }
}
