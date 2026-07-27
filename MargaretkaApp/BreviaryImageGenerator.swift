import Foundation
import FoundationModels
import ImagePlayground
import Translation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

actor BreviaryImageGenerator {
    static let shared = BreviaryImageGenerator()

    nonisolated static let fullCanvasConcept = """
        Put the camera inside the specified location and continue the scene all the way to all four canvas edges. Do not show a border, frame, mat, margin, blank edge, white edge, card, poster, page, picture, painting, photograph, screen, or artwork containing the scene. No people, text, letters, logos, or signs.
        """

    private var attemptedFingerprints = Set<String>()
    private var preparedPrompts: [String: String] = [:]

    func generateImageData(for office: OfflineBreviaryOffice) async -> Data? {
        guard attemptedFingerprints.insert(office.contentFingerprint).inserted else { return nil }

        do {
            let prompt = await preparedPrompt(for: office)

            let creator = try await ImageCreator()
            let style = creator.availableStyles.contains(.illustration)
                ? ImagePlaygroundStyle.illustration
                : (creator.availableStyles.first ?? .animation)
            let concepts: [ImagePlaygroundConcept] = [
                .text(prompt),
                .text(Self.fullCanvasConcept)
            ]
            for try await created in creator.images(for: concepts, style: style, limit: 1) {
                #if canImport(UIKit)
                return UIImage(cgImage: created.cgImage).jpegData(compressionQuality: 0.88)
                #elseif canImport(AppKit)
                let image = NSImage(cgImage: created.cgImage, size: .zero)
                return image.tiffRepresentation
                    .flatMap { NSBitmapImageRep(data: $0) }
                    .flatMap { $0.representation(using: .jpeg, properties: [:]) }
                #else
                return nil
                #endif
            }
        } catch {
            print("Breviary image generation unavailable: \(error.localizedDescription)")
        }
        return nil
    }

    func preparedPrompt(for office: OfflineBreviaryOffice) async -> String {
        if let cached = preparedPrompts[office.contentFingerprint] { return cached }
        let fallback = Self.concreteFallbackPrompt(for: office.key)
        var sourceContext = office.imagePrompt ?? ""
        if let source = office.imageSourceText, !source.isEmpty,
           let translation = try? await translateInstalledPolishToEnglish(source) {
            sourceContext += "\nEnglish translation of the source excerpt:\n\(translation)"
        }
        let prompt = await concretePromptWhenAvailable(
            sourceContext: sourceContext,
            fallback: fallback
        )
        preparedPrompts[office.contentFingerprint] = prompt
        return prompt
    }

    func preparedPrompt(forPrayerName name: String) async -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = "prayer-target:\(trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL")))"
        if let cached = preparedPrompts[cacheKey] { return cached }

        let fallback = """
            Inside a small stone room at dawn, a worn oak table fills the foreground beneath an open arched window. A clay lamp, a glass of water, a sprig of rosemary, a folded linen cloth, and a string of wooden beads rest directly on the tabletop. Beyond the window, a narrow garden path leads between olive trees toward low blue hills. Sunlight enters from the left and casts long shadows. Use warm stone, oak brown, olive green, and pale blue. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        let context = trimmedName.isEmpty
            ? "No source name is available."
            : "Name from the Polish source: \(trimmedName)"
        let prompt = await concretePromptWhenAvailable(
            sourceContext: context,
            fallback: fallback
        )
        preparedPrompts[cacheKey] = prompt
        return prompt
    }

    private func translateInstalledPolishToEnglish(_ text: String) async throws -> String {
        let polish = Locale.Language(identifier: "pl")
        let english = Locale.Language(identifier: "en")
        let session = TranslationSession(installedSource: polish, target: english)
        return try await session.translate(text).targetText
    }

    private func concretePromptWhenAvailable(
        sourceContext: String,
        fallback: String
    ) async -> String {
        guard SystemLanguageModel.default.isAvailable else { return fallback }
        do {
            let session = LanguageModelSession(instructions: """
                Write one English prompt for a vertical wallpaper image.
                Describe only things a camera could see: one exact location, the foreground surface, three to six named physical objects, the background, time of day, weather, direction of light, and a small color palette.
                Place the camera inside the location and make the location continue through all four canvas edges. Never describe a framed image, print, card, poster, page, painting, photograph, screen, border, mat, margin, blank edge, or white edge.
                Use source names and excerpts only to choose fitting physical objects. Do not summarize or name the source material.
                Never use abstract religious, emotional, or artistic labels. Never use words including Catholic, sacred, prayer, liturgy, spiritual, symbolic, contemplative, reverent, holy, faith, devotional, or theme.
                Do not mention writing, captions, logos, signs, letters, or abstract symbols except in the final prohibition sentence.
                Write 60 to 100 words. Start immediately with the location. End with: No people, text, letters, logos, or signs.
                """)
            let response = try await session.respond(to: sourceContext)
            let candidate = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !Self.containsAbstractLanguage(candidate),
                  candidate.split(whereSeparator: \.isWhitespace).count >= 35 else {
                return fallback
            }
            return candidate
        } catch {
            return fallback
        }
    }

    nonisolated static func containsAbstractLanguage(_ prompt: String) -> Bool {
        let normalized = prompt.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let forbidden = [
            "catholic", "sacred", "prayer", "liturgy", "spiritual",
            "symbolic", "contemplative", "reverent", "holy", "faith",
            "devotional", "theme"
        ]
        return forbidden.contains { normalized.contains($0) }
    }

    nonisolated static func concreteFallbackPrompt(for key: BrewiarzPrayerKey) -> String {
        switch key {
        case .msza:
            return """
            Inside a small stone church, a white linen cloth covers a wooden altar in the foreground. A gold chalice and a round paten stand between two burning beeswax candles. Three narrow stained-glass windows and a plain semicircular apse fill the background. Warm morning light enters from the left, making long amber shadows across the pale floor. Use cream, dark wood, muted red, and gold. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .wezwanie:
            return """
            On a rocky hillside before sunrise, an open wooden gate stands beside a narrow path in the foreground. Dew covers the grass, and three old olive trees frame the path as it climbs toward distant blue mountains. A clay water jug rests against one gatepost. A thin orange band of light appears along the horizon beneath a deep blue sky. Use slate blue, olive green, clay brown, and pale orange. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .godzinaCzytan:
            return """
            Inside a stone monastery library at night, a heavy wooden reading desk fills the foreground. An open old book, a brass oil lamp, a pair of round spectacles, and a folded linen cloth rest on the desk. Tall shelves of dark leather-bound books recede toward an arched window showing a starry sky. The lamp casts a small pool of warm light and deep shadows. Use walnut brown, brass, charcoal, and amber. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .jutrznia:
            return """
            In a walled monastery garden at sunrise, a round stone fountain stands in the foreground beside white lilies wet with dew. A gravel path crosses between trimmed rosemary bushes and leads to a simple arched doorway in the far wall. Two swallows fly above terracotta roof tiles. Low sunlight enters through the arch and makes long shadows across the path. Use pale gold, leaf green, white, and warm stone. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .modlitwaPrzedpoludniowa:
            return """
            In a sunlit cloister courtyard during midmorning, a terracotta pot with a small lemon tree stands on worn stone paving in the foreground. A wooden bench, a shallow water basin, and a coiled garden rope sit beneath the surrounding arches. Beyond the arcade, a square bell tower rises into a clear blue sky. Crisp sunlight falls from the upper right and creates striped shadows. Use limestone, lemon yellow, leaf green, and sky blue. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .modlitwaPoludniowa:
            return """
            At the edge of a wheat field at noon, a circular stone well occupies the foreground. A wooden bucket, a length of rope, and a clay cup rest on its sun-warmed rim. Straight rows of golden wheat lead toward a low farmhouse and a line of cypress trees on the horizon. The cloudless sky is bright blue, and short shadows fall directly beneath every object. Use wheat gold, dusty beige, cypress green, and blue. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .modlitwaPopoludniowa:
            return """
            In an olive grove during late afternoon, a low dry-stone wall crosses the foreground beside a wicker basket holding green olives. A folded ochre cloth, a pruning knife, and a small ceramic flask lie on the wall. Gnarled olive trunks continue down a gentle slope toward distant vineyards. Warm sunlight comes from the right and catches silver leaves moving in a light breeze. Use olive green, silver, ochre, and warm gray. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .nieszpory:
            return """
            Beside a slow river at sunset, a weathered stone landing fills the foreground with a brass lantern, a folded blue cloth, and a small wooden boat tied to an iron ring. A single-arch bridge spans the water in the middle distance, with dark cypress trees and low hills beyond it. The orange sky reflects in long bands across the water while the lantern begins to glow. Use burnt orange, deep blue, charcoal, and brass. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        case .kompleta:
            return """
            Inside a small whitewashed chapel at night, a narrow wooden table stands in the foreground beneath an arched window. A closed book, a brass oil lamp, a glass of water, and a sprig of lavender rest on the table. The window reveals a crescent moon and scattered stars above dark hills. The lamp produces a soft amber circle surrounded by cool blue shadows. Use midnight blue, chalk white, lavender gray, and amber. Vertical wallpaper composition. No people, text, letters, logos, or signs.
            """
        }
    }
}
