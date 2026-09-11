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
        #expect(PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion == 9)
    }

    @Test func audioDominatesCombinedInput() {
        let audio = PrayerAutoAdvanceAudioFeatureExtractor.featureCount
            + PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount
        let ratio = Double(audio) / Double(PrayerAutoAdvanceCoreMLModel.combinedInputSize)
        #expect(audio == 6_240)
        #expect(ratio > 0.85)
    }
}
