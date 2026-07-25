//
//  MargaretkaAppUITestsLaunchTests.swift
//  MargaretkaAppUITests
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import XCTest

final class MargaretkaAppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        let launchStart = Date()
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 1),
            "MargaretkaApp did not reach the foreground within 1 second"
        )
        XCTAssertTrue(
            app.otherElements["prayer_flow_view"].waitForExistence(timeout: 1),
            "Logged-in MargaretkaApp did not present PrayerFlowView within 1 second"
        )
        XCTAssertLessThanOrEqual(
            Date().timeIntervalSince(launchStart),
            1.0,
            "Logged-in MargaretkaApp took longer than 1 second to present PrayerFlowView"
        )

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchRemainsForegroundForThreeMinutes() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 1),
            "MargaretkaApp did not reach the foreground within 1 second"
        )

        for second in stride(from: 5, through: 180, by: 5) {
            sleep(5)
            XCTAssertEqual(
                app.state,
                .runningForeground,
                "MargaretkaApp stopped running in the foreground after approximately \(second) seconds"
            )
        }
    }
}
