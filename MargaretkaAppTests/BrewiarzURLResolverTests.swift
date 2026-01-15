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
        let baseURL = URL(string: "https://brewiarz.pl/dzis.php")!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL)

        XCTAssertEqual(url?.absoluteString, "https://brewiarz.pl/1501p/index.php3?l=i")
    }

    func testFirstOfficiumIndexURLParsesUnquotedHref() async {
        let html = """
        <html><body>
        <a href=../1501p/index.php3?l=i>Oficjum 1</a>
        <a href=../1501w/index.php3?l=i>Oficjum 2</a>
        </body></html>
        """
        let baseURL = URL(string: "https://brewiarz.pl/dzis.php")!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL)

        XCTAssertEqual(url?.absoluteString, "https://brewiarz.pl/1501p/index.php3?l=i")
    }

    func testFirstOfficiumIndexURLReturnsNilWhenMissing() async {
        let html = """
        <html><body>
        <a href="https://example.com">Nope</a>
        </body></html>
        """
        let baseURL = URL(string: "https://brewiarz.pl/dzis.php")!
        let resolver = await BrewiarzURLResolver.shared
        let url = await resolver.firstOfficiumIndexURL(in: html, baseURL: baseURL)

        XCTAssertNil(url)
    }
}
