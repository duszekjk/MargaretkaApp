import Foundation
import FoundationModels
import ImagePlayground
import Translation
import UIKit

actor BreviaryImageGenerator {
    static let shared = BreviaryImageGenerator()

    private var attemptedFingerprints = Set<String>()

    func generateImageData(for office: OfflineBreviaryOffice) async -> Data? {
        guard attemptedFingerprints.insert(office.contentFingerprint).inserted else { return nil }

        do {
            var prompt = office.imagePrompt ?? defaultPrompt(for: office.key)
            if let source = office.imageSourceText, !source.isEmpty,
               let translation = try? await translateInstalledPolishToEnglish(source) {
                prompt += "\nOffline Polish-to-English translation of the prayer themes:\n\(translation)"
            }
            prompt = await refinePromptWhenAvailable(prompt)

            let creator = try await ImageCreator()
            let style = creator.availableStyles.contains(.illustration)
                ? ImagePlaygroundStyle.illustration
                : (creator.availableStyles.first ?? .animation)
            let concepts: [ImagePlaygroundConcept] = [
                .text(prompt),
                .text("Catholic sacred art, contemplative, no visible text or lettering")
            ]
            for try await created in creator.images(for: concepts, style: style, limit: 1) {
                return UIImage(cgImage: created.cgImage).jpegData(compressionQuality: 0.88)
            }
        } catch {
            print("Breviary image generation unavailable: \(error.localizedDescription)")
        }
        return nil
    }

    private func translateInstalledPolishToEnglish(_ text: String) async throws -> String {
        let polish = Locale.Language(identifier: "pl")
        let english = Locale.Language(identifier: "en")
        let session = TranslationSession(installedSource: polish, target: english)
        return try await session.translate(text).targetText
    }

    private func refinePromptWhenAvailable(_ source: String) async -> String {
        guard SystemLanguageModel.default.isAvailable else { return source }
        do {
            let session = LanguageModelSession(instructions: """
                You turn Catholic prayer metadata and short quotations into one concise English visual scene prompt.
                Preserve the named office, translated feast, and liturgical color. Polish may appear only as quoted input.
                Return visual description only. Never request writing, lettering, captions, or words inside the image.
                """)
            let response = try await session.respond(to: source)
            return response.content
        } catch {
            return source
        }
    }

    private func defaultPrompt(for key: BrewiarzPrayerKey) -> String {
        "A calm Catholic \(key.displayName) prayer scene, sacred light, symbolic landscape, no text or letters."
    }
}
