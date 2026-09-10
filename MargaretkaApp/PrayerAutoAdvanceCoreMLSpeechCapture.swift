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

    nonisolated private let requestBox = PrayerAutoAdvanceSpeechRequestBox()
    nonisolated private let transcriptBox = PrayerAutoAdvanceTranscriptBox()
    nonisolated private let audioRing = PrayerAutoAdvanceAudioRingBuffer(
        duration: PrayerAutoAdvanceLongAudioFeatureExtractor.duration + 0.5,
        targetSampleRate: 16_000
    )
    // Raw PCM remains RAM-only and page-scoped. This lets training candidates keep
    // only an audio endpoint while exact V11 features are materialized after swipe.
    nonisolated private let pageAudio = PrayerAutoAdvancePageAudioBuffer(targetSampleRate: 16_000)

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
        pageAudio.configure(sourceSampleRate: format.sampleRate)

        let requestBox = self.requestBox
        let audioRing = self.audioRing
        let pageAudio = self.pageAudio
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            requestBox.append(buffer)
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            audioRing.append(channel, count: count)
            pageAudio.append(channel, count: count)
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
        transcriptBox.reset(generation: generation)
        audioRing.reset()
        pageAudio.reset()

        let transcriptBox = self.transcriptBox
        task = recognizer.recognitionTask(with: speechRequest) { [weak self] result, error in
            if let result {
                transcriptBox.set(result.bestTranscription.formattedString, generation: generation)
            }

            if error != nil {
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionGeneration == generation else { return }
                    self.stopRecognition()
                    self.stopAudioOnly(deactivateSession: true)
                }
            }
        }
    }

    private func stopRecognition() {
        recognitionGeneration += 1
        requestBox.set(nil)
        transcriptBox.reset(generation: recognitionGeneration)
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
    }

    nonisolated func transcriptSnapshot() -> String { transcriptBox.snapshot() }
    nonisolated func pageAudioSampleIndex() -> Int { pageAudio.sampleCount() }
    nonisolated func freezePageAudio() -> PrayerAutoAdvanceAudioWindow { pageAudio.freeze() }

    func audioWindow() -> PrayerAutoAdvanceAudioWindow { audioRing.snapshot() }

    nonisolated func audioWindowOffMain() async -> PrayerAutoAdvanceAudioWindow {
        let ring = audioRing
        return await Task.detached(priority: .background) { ring.snapshot() }.value
    }

    func stop() {
        stopRecognition()
        stopAudioOnly(deactivateSession: true)
        audioRing.reset()
        pageAudio.reset()
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
            Task { try? await Self.setAudioSessionActive(false) }
        }
    }

    nonisolated private static func configureAudioSessionForCapture() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
                    // Recording sessions suppress system haptics by default. Prayer
                    // navigation feedback must remain identical while training listens.
                    try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
                    try session.setActive(true)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
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
                } catch { continuation.resume(throwing: error) }
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
        lock.lock(); request = value; lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); let current = request; lock.unlock()
        current?.append(buffer)
    }
}

private final class PrayerAutoAdvanceTranscriptBox: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = 0
    private var text = ""

    func reset(generation: Int) {
        lock.lock(); self.generation = generation; text = ""; lock.unlock()
    }

    func set(_ value: String, generation: Int) {
        lock.lock()
        if self.generation == generation { text = value }
        lock.unlock()
    }

    func snapshot() -> String {
        lock.lock(); let value = text; lock.unlock(); return value
    }
}

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
        lock.lock(); self.sourceSampleRate = max(sourceSampleRate, 1); sourcePhase = 0; lock.unlock()
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
            if start < capacity { samples.append(contentsOf: storage[start..<capacity]) }
            if start > 0 { samples.append(contentsOf: storage[0..<start]) }
        } else if count > 0 {
            samples.append(contentsOf: storage[0..<count])
        }
        lock.unlock()
        return PrayerAutoAdvanceAudioWindow(samples: samples, sampleRate: targetSampleRate)
    }

    func reset() {
        lock.lock(); writeIndex = 0; storedCount = 0; sourcePhase = 0; lock.unlock()
    }
}

/// Page-scoped Float32 PCM history. It is never persisted or uploaded. Keeping one
/// shared stream is far cheaper than storing sixteen overlapping 60 s snapshots.
private final class PrayerAutoAdvancePageAudioBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let targetSampleRate: Double
    private var sourceSampleRate: Double = 48_000
    private var sourcePhase: Double = 0
    private var storage: [Float] = []

    init(targetSampleRate: Double) {
        self.targetSampleRate = targetSampleRate
        storage.reserveCapacity(Int(targetSampleRate * 300))
    }

    func configure(sourceSampleRate: Double) {
        lock.lock(); self.sourceSampleRate = max(sourceSampleRate, 1); sourcePhase = 0; lock.unlock()
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
        lock.unlock()
    }

    func sampleCount() -> Int {
        lock.lock(); let count = storage.count; lock.unlock(); return count
    }

    /// Detaches the old page in O(1) via Array copy-on-write semantics. The returned
    /// samples remain RAM-only while the live recorder immediately starts a fresh page.
    func freeze() -> PrayerAutoAdvanceAudioWindow {
        lock.lock()
        let frozen = storage
        storage = []
        sourcePhase = 0
        lock.unlock()
        return PrayerAutoAdvanceAudioWindow(samples: frozen, sampleRate: targetSampleRate)
    }

    func reset() {
        lock.lock(); storage = []; sourcePhase = 0; lock.unlock()
    }
}
#endif
