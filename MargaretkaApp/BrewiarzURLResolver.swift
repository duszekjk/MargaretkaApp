//
//  BrewiarzURLResolver.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 18/01/2026.
//

import Foundation

struct BrewiarzDailyLinks: Codable, Hashable {
    let dateKey: String
    let chosenOfficiumIndexURL: String
    let prayerLinks: [BrewiarzPrayerKey: String]
    let miscLinks: [String]
}

actor BrewiarzURLResolver {
    static let shared = BrewiarzURLResolver()

    private let cacheKey = "brewiarz_daily_links"
    private var cachedLinks: BrewiarzDailyLinks?

    func resolveURL(for key: BrewiarzPrayerKey, date: Date = .now) async -> URL? {
        do {
            let resolved = try await resolveLinks(for: date)
            if let urlString = resolved.prayerLinks[key] {
                return URL(string: urlString)
            }
            return URL(string: resolved.chosenOfficiumIndexURL)
        } catch {
            return URL(string: "https://brewiarz.pl/dzis.php")
        }
    }

    private func resolveLinks(for date: Date) async throws -> BrewiarzDailyLinks {
        let dateKey = Self.dateKey(for: date)
        if let cachedLinks, cachedLinks.dateKey == dateKey {
            return cachedLinks
        }
        if let stored = loadCache(dateKey: dateKey) {
            cachedLinks = stored
            return stored
        }

        let dzisURL = URL(string: "https://brewiarz.pl/dzis.php")!
        let (dzisHTML, dzisFinalURL) = try await fetchHTML(from: dzisURL)

        let indexURL: URL
        if let resolvedIndex = firstOfficiumIndexURL(in: dzisHTML, baseURL: dzisFinalURL) {
            indexURL = resolvedIndex
        } else {
            indexURL = dzisFinalURL
        }

        let (indexHTML, indexFinalURL) = try await fetchHTML(from: indexURL)
        let anchors = parseAnchors(from: indexHTML)

        var prayerLinks: [BrewiarzPrayerKey: String] = [:]
        var miscLinks: [String] = []

        for anchor in anchors {
            guard let resolvedURL = resolveURL(href: anchor.href, baseURL: indexFinalURL) else { continue }
            guard resolvedURL.host == "brewiarz.pl" else { continue }
            guard resolvedURL.path.contains("/i_") else { continue }
            guard resolvedURL.path.lowercased().hasSuffix(".php3") else { continue }

            if let key = mapKey(for: resolvedURL, anchorText: anchor.text) {
                if prayerLinks[key] == nil {
                    prayerLinks[key] = resolvedURL.absoluteString
                }
            } else {
                miscLinks.append(resolvedURL.absoluteString)
            }
        }

        let resolved = BrewiarzDailyLinks(
            dateKey: dateKey,
            chosenOfficiumIndexURL: indexFinalURL.absoluteString,
            prayerLinks: prayerLinks,
            miscLinks: miscLinks
        )
        saveCache(resolved)
        cachedLinks = resolved
        return resolved
    }

    private func fetchHTML(from url: URL) async throws -> (String, URL) {
        let (data, response) = try await URLSession.shared.data(from: url)
        let html = String(decoding: data, as: UTF8.self)
        let finalURL = (response as? HTTPURLResponse)?.url ?? url
        return (html, finalURL)
    }

    private func firstOfficiumIndexURL(in html: String, baseURL: URL) -> URL? {
        let anchors = parseAnchors(from: html)
        for anchor in anchors {
            if anchor.href.lowercased().contains("index.php3?l=i") {
                return resolveURL(href: anchor.href, baseURL: baseURL)
            }
        }
        return nil
    }

    private func parseAnchors(from html: String) -> [(href: String, text: String)] {
        let pattern = "<a\\s+[^>]*href\\s*=\\s*['\"]([^'\"]+)['\"][^>]*>(.*?)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        return matches.compactMap { match in
            guard let hrefRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else {
                return nil
            }
            let href = String(html[hrefRange])
            let rawText = String(html[textRange])
            let text = stripHTML(rawText)
            return (href: href, text: text)
        }
    }

    private func stripHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveURL(href: String, baseURL: URL) -> URL? {
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            return URL(string: href)
        }
        if href.hasPrefix("/") {
            return URL(string: "https://brewiarz.pl\(href)")
        }
        return URL(string: href, relativeTo: baseURL)?.absoluteURL
    }

    private func mapKey(for url: URL, anchorText: String) -> BrewiarzPrayerKey? {
        let filename = url.lastPathComponent.lowercased()
        switch filename {
        case "wezwanie.php3":
            return .wezwanie
        case "godzczyt.php3":
            return .godzinaCzytan
        case "jutrznia.php3":
            return .jutrznia
        case "modlitwa1.php3":
            return .modlitwaPrzedpoludniowa
        case "modlitwa2.php3":
            return .modlitwaPoludniowa
        case "modlitwa3.php3":
            return .modlitwaPopoludniowa
        case "modlitwa.php3":
            return .modlitwaPoludniowa
        case "nieszpory.php3":
            return .nieszpory
        case "kompleta.php3":
            return .kompleta
        default:
            break
        }

        let normalized = normalize(anchorText)
        if normalized.contains("wezwanie") {
            return .wezwanie
        }
        if normalized.contains("godzina czytan") {
            return .godzinaCzytan
        }
        if normalized.contains("jutrznia") {
            return .jutrznia
        }
        if normalized.contains("przedpoludniowa") {
            return .modlitwaPrzedpoludniowa
        }
        if normalized.contains("popoludniowa") {
            return .modlitwaPopoludniowa
        }
        if normalized.contains("poludniowa") {
            return .modlitwaPoludniowa
        }
        if normalized.contains("nieszpory") {
            return .nieszpory
        }
        if normalized.contains("kompleta") {
            return .kompleta
        }
        return nil
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func dateKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func loadCache(dateKey: String) -> BrewiarzDailyLinks? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(BrewiarzDailyLinks.self, from: data),
              cached.dateKey == dateKey else {
            return nil
        }
        return cached
    }

    private func saveCache(_ cache: BrewiarzDailyLinks) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
