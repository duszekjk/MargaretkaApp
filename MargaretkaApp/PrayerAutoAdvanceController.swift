import AVFoundation
import Foundation
import NaturalLanguage
import Speech
internal import Combine

struct PrayerAutoAdvanceContext: Equatable, Sendable {
    let pageID: String
    let currentText: String
    let previousText: String?
    let nextText: String?
    let language: PrayerLanguage
}

private struct PrayerAutoAdvanceSnapshot {
    let pageID: String
    let date: Date
    let features: [Float]
}

@MainActor
final class PrayerAutoAdvanceController: ObservableObject {
    @Published private(set) var advanceRequestSerial = 0
    @Published private(set) var lastPrediction: Float = 0
    @Published private(set) var statusMessage: String?

    private let store = PrayerAutoAdvanceStore.shared
#if os(iOS)
    private let capture = PrayerSpeechCapture()
#endif
    private var context: PrayerAutoAdvanceContext?
    private var contextStartedAt = Date()
    private var snapshots: [PrayerAutoAdvanceSnapshot] = []
    private var evaluationTask: Task<Void, Never>?
    private var consecutiveAdvancePredictions = 0
    private var cooldownUntil = Date.distantPast

    deinit {
        evaluationTask?.cancel()
    }

    func setContext(_ newContext: PrayerAutoAdvanceContext?) {
        guard context != newContext else { return }
        context = newContext
        contextStartedAt = Date()
        snapshots.removeAll(keepingCapacity: true)
        consecutiveAdvancePredictions = 0
        lastPrediction = 0

        guard newContext != nil, isFeatureEnabled else {
            stopListening()
            return
        }
        startEvaluationLoop()
        Task { @MainActor [weak self] in
            await self?.prepareListeningForCurrentContext()
        }
    }

    func preferencesDidChange() {
        if isFeatureEnabled, context != nil {
            startEvaluationLoop()
            Task { @MainActor [weak self] in
                await self?.prepareListeningForCurrentContext()
            }
        } else {
            stopListening()
        }
    }

    func recordManualAdvance() {
        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey),
              var model = store.model,
              let context else { return }

        let candidates = snapshots.filter { $0.pageID == context.pageID }
        guard !candidates.isEmpty else { return }

        let positives = Array(candidates.suffix(2))
        let positiveIDs = Set(positives.map(\.date))
        let negatives = candidates
            .filter { !positiveIDs.contains($0.date) && Date().timeIntervalSince($0.date) > 2.0 }
            .suffix(6)

        var batch: [(features: [Float], label: Float)] = negatives.map { ($0.features, 0) }
        batch.append(contentsOf: positives.map { ($0.features, 1) })
        guard batch.contains(where: { $0.label > 0.5 }) else { return }

        for _ in 0..<3 {
            model.train(samples: batch, learningRate: 0.008)
        }
        do {
            try store.updateModel(model)
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func stop() {
        context = nil
        evaluationTask?.cancel()
        evaluationTask = nil
        stopListening()
    }

    private var isFeatureEnabled: Bool {
        UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey)
            || UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey)
    }

    private func startEvaluationLoop() {
        guard evaluationTask == nil else { return }
        evaluationTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                await self.evaluateCurrentState()
                try? await Task.sleep(for: .milliseconds(750))
            }
        }
    }

    private func prepareListeningForCurrentContext() async {
        guard let context, isFeatureEnabled else { return }
        guard await store.ensureModelAvailable() else {
            statusMessage = store.lastError ?? "Nie udało się przygotować modelu automatycznego przełączania."
            return
        }
#if os(iOS)
        do {
            try await capture.start(
                language: context.language,
                contextualStrings: [context.currentText, context.nextText].compactMap { $0 }
            )
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
#endif
    }

    private func evaluateCurrentState() async {
        guard let context, let model = store.model, isFeatureEnabled else { return }
#if os(iOS)
        let transcript = capture.transcript
        let energy = capture.energy
        let silence = capture.silenceDuration
#else
        let transcript = ""
        let energy: Float = 0
        let silence: TimeInterval = 0
#endif
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let elapsed = Date().timeIntervalSince(contextStartedAt)
        let features = PrayerAutoAdvanceFeatureExtractor.features(
            transcript: transcript,
            context: context,
            elapsed: elapsed,
            silence: silence,
            energy: energy
        )
        guard features.count == PrayerAutoAdvanceModelPayload.inputSize else { return }

        snapshots.append(PrayerAutoAdvanceSnapshot(pageID: context.pageID, date: Date(), features: features))
        if snapshots.count > 30 { snapshots.removeFirst(snapshots.count - 30) }

        let prediction = model.prediction(for: features)
        lastPrediction = prediction

        guard UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.automaticEnabledKey),
              Date() >= cooldownUntil,
              elapsed >= 2.0 else {
            consecutiveAdvancePredictions = 0
            return
        }

        if prediction >= 0.96 {
            consecutiveAdvancePredictions += 1
        } else {
            consecutiveAdvancePredictions = 0
        }
        if consecutiveAdvancePredictions >= 3 {
            consecutiveAdvancePredictions = 0
            cooldownUntil = Date().addingTimeInterval(3)
            advanceRequestSerial &+= 1
        }
    }

    private func stopListening() {
        evaluationTask?.cancel()
        evaluationTask = nil
#if os(iOS)
        capture.stop()
#endif
    }
}

enum PrayerAutoAdvanceFeatureExtractor {
    static func features(
        transcript: String,
        context: PrayerAutoAdvanceContext,
        elapsed: TimeInterval,
        silence: TimeInterval,
        energy: Float
    ) -> [Float] {
        let currentSemantic = semanticSimilarity(transcript, context.currentText, language: context.language)
        let nextSemantic = context.nextText.map { semanticSimilarity(transcript, $0, language: context.language) } ?? 0
        let currentLexical = lexicalSimilarity(transcript, context.currentText)
        let nextLexical = context.nextText.map { lexicalSimilarity(transcript, $0) } ?? 0
        let ending = endingCoverage(transcript: transcript, expected: context.currentText)
        let elapsedNormalized = Float(min(max(elapsed / 120.0, 0), 1))
        let silenceNormalized = Float(min(max(silence / 4.0, 0), 1))
        let energyNormalized = min(max(energy * 10, 0), 1)
        let expectedWordCount = max(tokens(context.currentText).count, 1)
        let spokenRatio = Float(min(Double(tokens(transcript).count) / Double(expectedWordCount), 1))
        let semanticMargin = min(max((currentSemantic - nextSemantic + 1) / 2, 0), 1)

        return [
            currentSemantic,
            nextSemantic,
            currentLexical,
            nextLexical,
            ending,
            elapsedNormalized,
            silenceNormalized,
            energyNormalized,
            spokenRatio,
            semanticMargin
        ]
    }

    private static func semanticSimilarity(_ lhs: String, _ rhs: String, language: PrayerLanguage) -> Float {
        guard let nlLanguage = language.nlLanguage,
              let embedding = NLEmbedding.sentenceEmbedding(for: nlLanguage),
              let left = embedding.vector(for: normalized(lhs)),
              let right = embedding.vector(for: normalized(rhs)),
              left.count == right.count,
              !left.isEmpty else {
            return lexicalSimilarity(lhs, rhs)
        }
        var dot = 0.0
        var leftNorm = 0.0
        var rightNorm = 0.0
        for index in left.indices {
            dot += left[index] * right[index]
            leftNorm += left[index] * left[index]
            rightNorm += right[index] * right[index]
        }
        guard leftNorm > 0, rightNorm > 0 else { return 0 }
        let cosine = dot / (sqrt(leftNorm) * sqrt(rightNorm))
        return Float(min(max((cosine + 1) / 2, 0), 1))
    }

    private static func lexicalSimilarity(_ lhs: String, _ rhs: String) -> Float {
        let left = Set(tokens(lhs))
        let right = Set(tokens(rhs))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let intersection = left.intersection(right).count
        let union = left.union(right).count
        return Float(intersection) / Float(max(union, 1))
    }

    private static func endingCoverage(transcript: String, expected: String) -> Float {
        let spoken = tokens(transcript)
        let target = tokens(expected)
        guard !spoken.isEmpty, !target.isEmpty else { return 0 }
        let maximum = min(20, spoken.count, target.count)
        var matched = 0
        for length in stride(from: maximum, through: 1, by: -1) {
            if Array(spoken.suffix(length)) == Array(target.suffix(length)) {
                matched = length
                break
            }
        }
        return Float(matched) / Float(maximum)
    }

    private static func tokens(_ text: String) -> [String] {
        normalized(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
            .lowercased()
    }
}

private extension PrayerLanguage {
    var nlLanguage: NLLanguage? {
        switch self {
        case .polish: .polish
        case .english: .english
        case .latin: nil
        }
    }

    var speechLocale: Locale {
        switch self {
        case .polish: Locale(identifier: "pl_PL")
        case .english: Locale(identifier: "en_US")
        case .latin: Locale(identifier: "la")
        }
    }
}

#if os(iOS)
@MainActor
private final class PrayerSpeechCapture {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private(set) var transcript = ""
    private(set) var energy: Float = 0
    private var lastVoiceAt = Date()

    var silenceDuration: TimeInterval { Date().timeIntervalSince(lastVoiceAt) }

    func start(language: PrayerLanguage, contextualStrings: [String]) async throws {
        stop()
        try await requestPermissions()

        guard let recognizer = SFSpeechRecognizer(locale: language.speechLocale),
              recognizer.supportsOnDeviceRecognition else {
            throw CaptureError.onDeviceRecognitionUnavailable
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.contextualStrings = contextualStrings.map { String($0.prefix(500)) }
        request = recognitionRequest
        transcript = ""
        energy = 0
        lastVoiceAt = Date()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            let rms = Self.rms(buffer)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.energy = rms
                if rms > 0.012 { self.lastVoiceAt = Date() }
            }
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let result { self?.transcript = result.bestTranscription.formattedString }
                if error != nil { self?.stopAudioOnly() }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        stopAudioOnly()
        transcript = ""
    }

    private func stopAudioOnly() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async throws {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { throw CaptureError.speechPermissionDenied }

        let microphone = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard microphone else { throw CaptureError.microphonePermissionDenied }
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var meanSquare: Float = 0
        vDSP_measqv(channel, 1, &meanSquare, vDSP_Length(count))
        return sqrt(max(meanSquare, 0))
    }

    enum CaptureError: LocalizedError {
        case speechPermissionDenied
        case microphonePermissionDenied
        case onDeviceRecognitionUnavailable

        var errorDescription: String? {
            switch self {
            case .speechPermissionDenied: "Brak dostępu do rozpoznawania mowy."
            case .microphonePermissionDenied: "Brak dostępu do mikrofonu."
            case .onDeviceRecognitionUnavailable: "Rozpoznawanie mowy offline nie jest dostępne dla języka tej modlitwy na tym urządzeniu."
            }
        }
    }
}
#endif
