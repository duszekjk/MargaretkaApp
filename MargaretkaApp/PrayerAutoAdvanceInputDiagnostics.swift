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
    let spokenEmbeddingText: String
    let pageEmbeddingText: String
    let spokenTokens: [String]
    let pageTokens: [String]

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
        transcript: String,
        pageText: String,
        at date: Date
    ) {
        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey),
              date.timeIntervalSince(lastCaptureAt) >= Self.captureInterval else { return }
        lastCaptureAt = date

        let allSpokenTokens = Self.tokens(transcript)
        let spokenTokens = Array(allSpokenTokens.suffix(PrayerAutoAdvanceFeatureExtractor.spokenWindowWordCount))
        let spokenEmbeddingText = spokenTokens.joined(separator: " ")
        let pageTokens = Self.tokens(pageText)

        samples.append(
            PrayerAutoAdvanceDiagnosticInputSample(
                id: UUID(),
                date: date,
                pageID: pageID,
                prediction: prediction,
                features: features,
                longAudioFeatures: longAudioFeatures,
                pcmSamples: audioWindow.samples,
                sampleRate: audioWindow.sampleRate,
                spokenEmbeddingText: spokenEmbeddingText,
                pageEmbeddingText: pageText,
                spokenTokens: spokenTokens,
                pageTokens: pageTokens
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

    private static func tokens(_ text: String) -> [String] {
        text
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}

@MainActor
final class PrayerAutoAdvanceDiagnosticAudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var playingSampleID: UUID?
    @Published private(set) var playingDuration: TimeInterval?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var playbackToken: UUID?

    init() {
        engine.attach(player)
    }

    func isPlaying(sampleID: UUID, duration: TimeInterval) -> Bool {
        isPlaying && playingSampleID == sampleID && playingDuration == duration
    }

    func play(sampleID: UUID, duration: TimeInterval, samples: [Float], sampleRate: Double) throws {
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
            guard let baseAddress = source.baseAddress else { return }
            channel.update(from: baseAddress, count: samples.count)
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()

        let token = UUID()
        playbackToken = token
        playingSampleID = sampleID
        playingDuration = duration
        isPlaying = true

        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                guard let self, self.playbackToken == token else { return }
                self.playbackToken = nil
                self.playingSampleID = nil
                self.playingDuration = nil
                self.isPlaying = false
            }
        }
        player.play()
    }

    func stop() {
        playbackToken = nil
        player.stop()
        if engine.isRunning { engine.stop() }
        playingSampleID = nil
        playingDuration = nil
        isPlaying = false
    }
}
