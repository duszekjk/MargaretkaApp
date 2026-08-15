import AVFoundation
import Speech

#if os(iOS)
@MainActor
final class PrayerAutoAdvanceCoreMLSpeechCapture {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasInputTap = false
    private var isStarting = false
    private(set) var transcript = ""
    nonisolated private let audioRing = PrayerAutoAdvanceAudioRingBuffer(
        duration: PrayerAutoAdvanceLongAudioFeatureExtractor.duration,
        targetSampleRate: 8_000
    )

    func start(language: PrayerLanguage, context: [String]) async throws {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        stop()
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { throw CaptureError.permission }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard microphone else { throw CaptureError.permission }

        let locale = language == .english
            ? Locale(identifier: "en_US")
            : language == .latin
                ? Locale(identifier: "la")
                : Locale(identifier: "pl_PL")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else {
            throw CaptureError.offlineUnavailable
        }

        let speechRequest = SFSpeechAudioBufferRecognitionRequest()
        speechRequest.shouldReportPartialResults = true
        speechRequest.requiresOnDeviceRecognition = true
        speechRequest.contextualStrings = context.map { String($0.prefix(500)) }
        request = speechRequest
        transcript = ""
        audioRing.reset()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try await Self.setAudioSessionActive(true)

        let input = engine.inputNode
        if hasInputTap {
            input.removeTap(onBus: 0)
            hasInputTap = false
        }
        let format = input.outputFormat(forBus: 0)
        audioRing.configure(sourceSampleRate: format.sampleRate)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            speechRequest.append(buffer)
            guard let channel = buffer.floatChannelData?[0] else { return }
            self?.audioRing.append(channel, count: Int(buffer.frameLength))
        }
        hasInputTap = true

        do {
            engine.prepare()
            try engine.start()
        } catch {
            stopAudioOnly()
            throw error
        }

        task = recognizer.recognitionTask(with: speechRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let result { self?.transcript = result.bestTranscription.formattedString }
                if error != nil { self?.stopAudioOnly() }
            }
        }
    }

    func audioWindow() -> PrayerAutoAdvanceAudioWindow {
        audioRing.snapshot()
    }

    func stop() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        stopAudioOnly()
        transcript = ""
        audioRing.reset()
    }

    private func stopAudioOnly() {
        if engine.isRunning { engine.stop() }
        if hasInputTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        Task {
            try? await Self.setAudioSessionActive(false)
        }
    }

    nonisolated private static func setAudioSessionActive(_ active: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try AVAudioSession.sharedInstance().setActive(
                        active,
                        options: active ? [] : [.notifyOthersOnDeactivation]
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    enum CaptureError: LocalizedError {
        case permission
        case offlineUnavailable

        var errorDescription: String? {
            switch self {
            case .permission: "Brak wymaganych uprawnień do mikrofonu lub rozpoznawania mowy."
            case .offlineUnavailable: "Rozpoznawanie mowy offline nie jest dostępne dla języka tej modlitwy na tym urządzeniu."
            }
        }
    }
}

private final class PrayerAutoAdvanceAudioRingBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let duration: TimeInterval
    private let targetSampleRate: Double
    private var sourceSampleRate: Double = 48_000
    private var storage: [Float] = []
    private var sourcePhase: Double = 0

    init(duration: TimeInterval, targetSampleRate: Double) {
        self.duration = duration
        self.targetSampleRate = targetSampleRate
    }

    func configure(sourceSampleRate: Double) {
        lock.lock()
        self.sourceSampleRate = max(sourceSampleRate, 1)
        sourcePhase = 0
        trimLocked()
        lock.unlock()
    }

    func append(_ pointer: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        lock.lock()
        let step = sourceSampleRate / targetSampleRate
        var position = sourcePhase
        while position < Double(count) {
            let index = min(max(Int(position.rounded(.down)), 0), count - 1)
            storage.append(pointer[index])
            position += step
        }
        sourcePhase = position - Double(count)
        trimLocked()
        lock.unlock()
    }

    func snapshot() -> PrayerAutoAdvanceAudioWindow {
        lock.lock()
        let value = PrayerAutoAdvanceAudioWindow(samples: storage, sampleRate: targetSampleRate)
        lock.unlock()
        return value
    }

    func reset() {
        lock.lock()
        storage.removeAll(keepingCapacity: true)
        sourcePhase = 0
        lock.unlock()
    }

    private func trimLocked() {
        let maximumCount = max(1, Int((duration * targetSampleRate).rounded()))
        if storage.count > maximumCount {
            storage.removeFirst(storage.count - maximumCount)
        }
    }
}
#endif
