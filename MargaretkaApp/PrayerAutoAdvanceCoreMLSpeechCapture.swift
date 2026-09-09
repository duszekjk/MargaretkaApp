import AVFoundation
import Speech

#if os(iOS)
@MainActor
final class PrayerAutoAdvanceCoreMLSpeechCapture {
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var currentLanguage: PrayerLanguage?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasInputTap = false
    private var isStarting = false
    private var recognitionGeneration = 0
    private(set) var transcript = ""

    nonisolated private let requestBox = PrayerAutoAdvanceSpeechRequestBox()
    nonisolated private let audioRing = PrayerAutoAdvanceAudioRingBuffer(
        duration: PrayerAutoAdvanceLongAudioFeatureExtractor.duration + 0.5,
        targetSampleRate: 16_000
    )

    func start(language: PrayerLanguage, context: [String]) async throws {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        if engine.isRunning,
           currentLanguage == language,
           let recognizer,
           recognizer.supportsOnDeviceRecognition {
            beginRecognition(using: recognizer, context: context)
            return
        }

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
        guard let newRecognizer = SFSpeechRecognizer(locale: locale),
              newRecognizer.supportsOnDeviceRecognition else {
            throw CaptureError.offlineUnavailable
        }

        stopRecognition()
        stopAudioOnly(deactivateSession: false)
        recognizer = newRecognizer
        currentLanguage = language

        try await Self.configureAudioSessionForCapture()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        audioRing.configure(sourceSampleRate: format.sampleRate)

        let requestBox = self.requestBox
        let audioRing = self.audioRing
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            requestBox.append(buffer)
            guard let channel = buffer.floatChannelData?[0] else { return }
            audioRing.append(channel, count: Int(buffer.frameLength))
        }
        hasInputTap = true

        do {
            engine.prepare()
            try engine.start()
        } catch {
            stopAudioOnly(deactivateSession: true)
            throw error
        }

        beginRecognition(using: newRecognizer, context: context)
    }

    private func beginRecognition(using recognizer: SFSpeechRecognizer, context: [String]) {
        stopRecognition()
        recognitionGeneration += 1
        let generation = recognitionGeneration

        let speechRequest = SFSpeechAudioBufferRecognitionRequest()
        speechRequest.shouldReportPartialResults = true
        speechRequest.requiresOnDeviceRecognition = true
        speechRequest.contextualStrings = context.map { String($0.prefix(500)) }

        request = speechRequest
        requestBox.set(speechRequest)
        transcript = ""
        audioRing.reset()

        task = recognizer.recognitionTask(with: speechRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, self.recognitionGeneration == generation else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil {
                    self.stopRecognition()
                    self.stopAudioOnly(deactivateSession: true)
                }
            }
        }
    }

    private func stopRecognition() {
        recognitionGeneration += 1
        requestBox.set(nil)
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
    }

    func audioWindow() -> PrayerAutoAdvanceAudioWindow {
        audioRing.snapshot()
    }

    nonisolated func audioWindowOffMain() async -> PrayerAutoAdvanceAudioWindow {
        let ring = audioRing
        return await Task.detached(priority: .background) {
            ring.snapshot()
        }.value
    }

    func stop() {
        stopRecognition()
        stopAudioOnly(deactivateSession: true)
        transcript = ""
        audioRing.reset()
        recognizer = nil
        currentLanguage = nil
    }

    private func stopAudioOnly(deactivateSession: Bool) {
        if engine.isRunning { engine.stop() }
        if hasInputTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        if deactivateSession {
            Task {
                try? await Self.setAudioSessionActive(false)
            }
        }
    }

    nonisolated private static func configureAudioSessionForCapture() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
                    try session.setActive(true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func setAudioSessionActive(_ active: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
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

private final class PrayerAutoAdvanceSpeechRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ value: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        request = value
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let current = request
        lock.unlock()
        current?.append(buffer)
    }
}

/// Fixed-capacity circular PCM buffer. The previous implementation used
/// Array.removeFirst after reaching 60.5 s, which shifted almost one million
/// Float values on every microphone callback at 16 kHz.
private final class PrayerAutoAdvanceAudioRingBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let targetSampleRate: Double
    private let capacity: Int
    private var sourceSampleRate: Double = 48_000
    private var storage: [Float]
    private var writeIndex = 0
    private var storedCount = 0
    private var sourcePhase: Double = 0

    init(duration: TimeInterval, targetSampleRate: Double) {
        self.targetSampleRate = targetSampleRate
        self.capacity = max(1, Int((duration * targetSampleRate).rounded()))
        self.storage = Array(repeating: 0, count: capacity)
    }

    func configure(sourceSampleRate: Double) {
        lock.lock()
        self.sourceSampleRate = max(sourceSampleRate, 1)
        sourcePhase = 0
        lock.unlock()
    }

    func append(_ pointer: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        lock.lock()
        let step = sourceSampleRate / targetSampleRate
        var position = sourcePhase
        while position < Double(count) {
            let index = min(max(Int(position.rounded(.down)), 0), count - 1)
            storage[writeIndex] = pointer[index]
            writeIndex += 1
            if writeIndex == capacity { writeIndex = 0 }
            if storedCount < capacity { storedCount += 1 }
            position += step
        }
        sourcePhase = position - Double(count)
        lock.unlock()
    }

    func snapshot() -> PrayerAutoAdvanceAudioWindow {
        lock.lock()
        let count = storedCount
        let start = count == capacity ? writeIndex : 0

        var samples: [Float] = []
        samples.reserveCapacity(count)
        if count == capacity {
            if start < capacity {
                samples.append(contentsOf: storage[start..<capacity])
            }
            if start > 0 {
                samples.append(contentsOf: storage[0..<start])
            }
        } else if count > 0 {
            samples.append(contentsOf: storage[0..<count])
        }
        lock.unlock()

        return PrayerAutoAdvanceAudioWindow(samples: samples, sampleRate: targetSampleRate)
    }

    func reset() {
        lock.lock()
        writeIndex = 0
        storedCount = 0
        sourcePhase = 0
        lock.unlock()
    }
}
#endif
