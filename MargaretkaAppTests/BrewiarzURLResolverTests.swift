//
//  BrewiarzURLResolverTests.swift
//  MargaretkaAppTests
//
//  Created by Jacek Kałużny on 18/01/2026.
//

import XCTest
@testable import MargaretkaApp

final class BrewiarzURLResolverTests: XCTestCase {
    func testFirstOfficiumIndexURLParsesQuotedHref() async {
        let html = """
        <html><body>
        <a href="../1501p/index.php3?l=i">Oficjum 1</a>
        <a href="../1501w/index.php3?l=i">Oficjum 2</a>
        </body></html>
        """
        let baseURL = URL(string: "https://brewiarz.pl/i_26/1501/wyb.php3")!
        let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "Europe/Warsaw"), year: 2026, month: 1, day: 15).date!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL, date: date)

        XCTAssertEqual(url?.absoluteString, "https://brewiarz.pl/i_26/1501p/index.php3?l=i")
    }

    func testFirstOfficiumIndexURLParsesUnquotedHref() async {
        let html = """
        <html><body>
        <a href=../1501p/index.php3?l=i>Oficjum 1</a>
        <a href=../1501w/index.php3?l=i>Oficjum 2</a>
        </body></html>
        """
        let baseURL = URL(string: "https://brewiarz.pl/i_26/1501/wyb.php3")!
        let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "Europe/Warsaw"), year: 2026, month: 1, day: 15).date!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL, date: date)

        XCTAssertEqual(url?.absoluteString, "https://brewiarz.pl/i_26/1501p/index.php3?l=i")
    }

    func testFirstOfficiumIndexURLReturnsNilWhenMissing() async {
        let html = """
        <html><body>
        <a href="https://example.com">Nope</a>
        </body></html>
        """
        let baseURL = URL(string: "https://brewiarz.pl/i_26/1501/wyb.php3")!
        let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "Europe/Warsaw"), year: 2026, month: 1, day: 15).date!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL, date: date)

        XCTAssertNil(url)
    }

    func testFirstOfficiumIndexURLParsesHrefWithoutClosingTag() async {
        let html = """
        <html><body>
        <a href="../1501p/index.php3?l=i">Oficjum 1
        <a href="../1501w/index.php3?l=i">Oficjum 2</a>
        </body></html>
        """
        let baseURL = URL(string: "https://brewiarz.pl/i_26/1501/wyb.php3")!
        let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "Europe/Warsaw"), year: 2026, month: 1, day: 15).date!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL, date: date)

        XCTAssertEqual(url?.absoluteString, "https://brewiarz.pl/i_26/1501p/index.php3?l=i")
    }

    func testFirstOfficiumIndexURLDecodesEntities() async {
        let html = """
        <html><body>
        <a href="../1501p/index.php3?l=i&amp;d=1">Oficjum 1</a>
        </body></html>
        """
        let baseURL = URL(string: "https://brewiarz.pl/dzis.php")!
        let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "Europe/Warsaw"), year: 2026, month: 1, day: 15).date!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL, date: date)

        XCTAssertEqual(url?.absoluteString, "https://brewiarz.pl/i_26/1501p/index.php3?l=i&d=1")
    }
}
