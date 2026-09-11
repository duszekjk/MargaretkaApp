import Testing
@testable import MargaretkaApp

struct PrayerAutoAdvanceModelSchemaTests {
    @Test func featureSchemaHasExpectedAudioPrimaryLayout() {
        #expect(PrayerAutoAdvanceFeatureExtractor.progressFeatureCount == 4)
        #expect(PrayerAutoAdvanceFeatureExtractor.textEmbeddingSize == 512)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.duration == 10)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.temporalBins == 50)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.frequencyBands == 48)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.featureCount == 2_400)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.analysisSampleRate == 16_000)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.duration == 60)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.temporalBins == 120)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.frequencyBands == 32)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount == 3_840)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.analysisSampleRate == 16_000)
        #expect(PrayerAutoAdvanceSpectralFrontEnd.analysisWindowSamples == 640)
        #expect(PrayerAutoAdvanceSpectralFrontEnd.hopSamples == 320)
        #expect(PrayerAutoAdvanceCoreMLModel.inputSize == 3_428)
        #expect(PrayerAutoAdvanceCoreMLModel.longAudioInputSize == 3_840)
        #expect(PrayerAutoAdvanceCoreMLModel.combinedInputSize == 7_268)
        #expect(PrayerAutoAdvanceCoreMLModel.currentModelVersion == 12)
        #expect(PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion == 9)
    }

    @Test func audioDominatesCombinedInput() {
        let audio = PrayerAutoAdvanceAudioFeatureExtractor.featureCount
            + PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount
        let ratio = Double(audio) / Double(PrayerAutoAdvanceCoreMLModel.combinedInputSize)
        #expect(audio == 6_240)
        #expect(ratio > 0.85)
    }

    @Test func fourthScalarStoresLastRecognizedSpeechSegmentEnd() {
        let context = PrayerAutoAdvanceContext(
            pageID: "schema-test",
            currentText: "Zdrowaś Maryjo",
            previousText: nil,
            nextText: nil,
            language: .polish
        )
        let features = PrayerAutoAdvanceFeatureExtractor.features(
            transcript: "Zdrowaś",
            context: context,
            elapsed: 60,
            lastSegmentEndTime: 150,
            audioFeatures: Array(
                repeating: 0,
                count: PrayerAutoAdvanceAudioFeatureExtractor.featureCount
            )
        )

        #expect(features.count == PrayerAutoAdvanceCoreMLModel.inputSize)
        #expect(abs(features[3] - 0.5) < 0.000_001)
    }

    @Test func streamingAndBatchFrontEndsProduceTheSameFeatures() {
        let sampleCount = Int(2.5 * PrayerAutoAdvanceSpectralFrontEnd.sampleRate)
        let samples = (0..<sampleCount).map { index in
            Float(sin(2 * Double.pi * 440 * Double(index) / PrayerAutoAdvanceSpectralFrontEnd.sampleRate)) * 0.2
        }
        let batch = PrayerAutoAdvanceSpectralFrontEnd.analyze(samples: samples)
        let cache = PrayerAutoAdvanceStreamingSpectralCache()
        var start = 0
        let chunkSizes = [137, 997, 320, 2_051, 511]
        var chunkIndex = 0
        while start < samples.count {
            let end = min(start + chunkSizes[chunkIndex % chunkSizes.count], samples.count)
            cache.ingest(samples: Array(samples[start..<end]), startingAt: start)
            start = end
            chunkIndex += 1
        }

        let streamed = cache.features(endingAt: samples.count)
        let expectedShort = batch.shortFeatures(endingAt: samples.count)
        let expectedLong = batch.longFeatures(endingAt: samples.count)
        #expect(maximumDifference(streamed.short, expectedShort) < 0.000_001)
        #expect(maximumDifference(streamed.long, expectedLong) < 0.000_001)
    }

    private func maximumDifference(_ lhs: [Float], _ rhs: [Float]) -> Float {
        guard lhs.count == rhs.count else { return .infinity }
        return zip(lhs, rhs).map { pair in abs(pair.0 - pair.1) }.max() ?? 0
    }
}
