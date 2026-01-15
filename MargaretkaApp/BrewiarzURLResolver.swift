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

    private let cacheKey = "brewiarz_daily_links_v2"
    private var cachedLinks: BrewiarzDailyLinks?

    func resolveURL(for key: BrewiarzPrayerKey, date: Date = .now) async -> URL? {
        do {
            print("🔎 Brewiarz resolve URL for \(key.rawValue) \(Self.dateKey(for: date))")
            let resolved = try await resolveLinks(for: date)
            print("✅ Brewiarz resolved index: \(resolved.chosenOfficiumIndexURL)")
            print("✅ Brewiarz prayer links count: \(resolved.prayerLinks.count)")
            if let urlString = resolved.prayerLinks[key] {
                print("➡️ Brewiarz link for \(key.rawValue): \(urlString)")
                return URL(string: urlString)
            }
            print("⚠️ Brewiarz missing key \(key.rawValue), falling back to index")
            return URL(string: resolved.chosenOfficiumIndexURL)
        } catch {
            print("❌ Brewiarz resolve failed: \(error.localizedDescription)")
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
        print("🌍 Brewiarz fetch dzis: \(dzisURL.absoluteString)")
        let (dzisHTML, dzisFinalURL) = try await fetchHTML(from: dzisURL)
        print("🌍 Brewiarz dzis final: \(dzisFinalURL.absoluteString)")

        let indexURL: URL
        if let resolvedIndex = firstOfficiumIndexURL(in: dzisHTML, baseURL: dzisFinalURL, date: date) {
            print("✅ Brewiarz picked officium index: \(resolvedIndex.absoluteString)")
            indexURL = resolvedIndex
        } else {
            print("⚠️ Brewiarz no officium index found, using dzis final")
            indexURL = dzisFinalURL
        }

        print("🌍 Brewiarz fetch index: \(indexURL.absoluteString)")
        let (indexHTML, indexFinalURL) = try await fetchHTML(from: indexURL)
        print("🌍 Brewiarz index final: \(indexFinalURL.absoluteString)")
        let anchors = parseAnchors(from: indexHTML)
        print("🔗 Brewiarz anchors: \(anchors.count)")

        var prayerLinks: [BrewiarzPrayerKey: String] = [:]
        var miscLinks: [String] = []

        for anchor in anchors {
            guard let resolvedURL = resolveURL(href: anchor.href, baseURL: indexFinalURL, date: date) else { continue }
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
        if isValidIndexURL(indexFinalURL), !resolved.prayerLinks.isEmpty {
            saveCache(resolved)
        }
        cachedLinks = resolved
        return resolved
    }

    private func fetchHTML(from url: URL) async throws -> (String, URL) {
        let (data, response) = try await URLSession.shared.data(from: url)
        let html = String(decoding: data, as: UTF8.self)
        let finalURL = (response as? HTTPURLResponse)?.url ?? url
        return (html, finalURL)
    }

    func firstOfficiumIndexURL(in html: String, baseURL: URL, date: Date = .now) -> URL? {
        let pattern = "href\\s*=\\s*(['\"]?)([^'\"\\s>]+)\\1"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        for match in matches {
            guard let hrefRange = Range(match.range(at: 2), in: html) else { continue }
            let rawHref = String(html[hrefRange])
            let href = decodeHTMLEntities(rawHref)
            if href.lowercased().contains("index.php3?l=i") {
                return resolveURL(href: href, baseURL: baseURL, date: date)
            }
        }
        return fallbackIndexURL(in: html, baseURL: baseURL, date: date)
    }

    private func parseAnchors(from html: String) -> [(href: String, text: String)] {
        let quotedPattern = "<a\\s+[^>]*href\\s*=\\s*['\"]([^'\"]+)['\"][^>]*>(.*?)</a>"
        let unquotedPattern = "<a\\s+[^>]*href\\s*=\\s*([^\\s>]+)[^>]*>(.*?)</a>"

        let patterns = [quotedPattern, unquotedPattern]
        var results: [(href: String, text: String)] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
                continue
            }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            for match in matches {
                guard let hrefRange = Range(match.range(at: 1), in: html),
                      let textRange = Range(match.range(at: 2), in: html) else {
                    continue
                }
                let href = String(html[hrefRange])
                let rawText = String(html[textRange])
                let text = stripHTML(rawText)
                results.append((href: href, text: text))
            }
        }
        return results
    }

    private func stripHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var decoded = text.replacingOccurrences(of: "&amp;", with: "&")
        decoded = decoded.replacingOccurrences(of: "&quot;", with: "\"")
        decoded = decoded.replacingOccurrences(of: "&apos;", with: "'")
        decoded = decoded.replacingOccurrences(of: "&#39;", with: "'")
        return decoded
    }

    private func fallbackIndexURL(in html: String, baseURL: URL, date: Date) -> URL? {
        let pattern = "(https?://[^\\s'\"<>]*index\\.php3\\?l=i[^\\s'\"<>]*)|(\\.{2}/[^\\s'\"<>]*index\\.php3\\?l=i[^\\s'\"<>]*)|(/[^\\s'\"<>]*index\\.php3\\?l=i[^\\s'\"<>]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        for match in matches {
            guard let matchRange = Range(match.range, in: html) else { continue }
            let rawHref = String(html[matchRange])
            let href = decodeHTMLEntities(rawHref)
            if href.lowercased().contains("index.php3?l=i") {
                return resolveURL(href: href, baseURL: baseURL, date: date)
            }
        }
        return nil
    }

    private func stripLeadingDotDots(from href: String) -> String {
        var trimmed = href
        while trimmed.hasPrefix("../") {
            trimmed = String(trimmed.dropFirst(3))
        }
        return trimmed
    }

    private static func yearSuffix(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let year = calendar.component(.year, from: date)
        return String(format: "%02d", year % 100)
    }

    private func resolveURL(href: String, baseURL: URL, date: Date) -> URL? {
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            return URL(string: href)
        }
        if href.hasPrefix("/") {
            return URL(string: "https://brewiarz.pl\(href)")
        }
        if href.hasPrefix("../"), !baseURL.path.contains("/i_") {
            let trimmed = stripLeadingDotDots(from: href)
            let yearSuffix = Self.yearSuffix(for: date)
            return URL(string: "https://brewiarz.pl/i_\(yearSuffix)/\(trimmed)")
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
              cached.chosenOfficiumIndexURL.lowercased().contains("index.php3?l=i"),
              !cached.chosenOfficiumIndexURL.lowercased().contains("wyb"),
              !cached.prayerLinks.isEmpty,
              cached.dateKey == dateKey else {
            return nil
        }
        return cached
    }

    private func saveCache(_ cache: BrewiarzDailyLinks) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func isValidIndexURL(_ url: URL) -> Bool {
        let lowercased = url.absoluteString.lowercased()
        return lowercased.contains("index.php3?l=i") && !lowercased.contains("wyb")
    }
}
