import Testing
@testable import MargaretkaApp

struct PrayerAutoAdvanceModelSchemaTests {
    @Test func featureSchemaHasExpectedAudioPrimaryLayout() {
        #expect(PrayerAutoAdvanceFeatureExtractor.progressFeatureCount == 3)
        #expect(PrayerAutoAdvanceFeatureExtractor.textEmbeddingSize == 512)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.duration == 10)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.temporalBins == 50)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.frequencyBands == 24)
        #expect(PrayerAutoAdvanceAudioFeatureExtractor.featureCount == 1_200)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.duration == 60)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.temporalBins == 120)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.frequencyBands == 16)
        #expect(PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount == 1_920)
        #expect(PrayerAutoAdvanceCoreMLModel.inputSize == 2_227)
        #expect(PrayerAutoAdvanceCoreMLModel.longAudioInputSize == 1_920)
        #expect(PrayerAutoAdvanceCoreMLModel.combinedInputSize == 4_147)
        #expect(PrayerAutoAdvanceCoreMLModel.currentFeatureSchemaVersion == 7)
    }

    @Test func audioDominatesCombinedInput() {
        let audio = PrayerAutoAdvanceAudioFeatureExtractor.featureCount
            + PrayerAutoAdvanceLongAudioFeatureExtractor.featureCount
        let ratio = Double(audio) / Double(PrayerAutoAdvanceCoreMLModel.combinedInputSize)
        #expect(audio == 3_120)
        #expect(ratio > 0.75)
    }
}
