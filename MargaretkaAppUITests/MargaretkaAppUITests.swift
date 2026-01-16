//
//  MargaretkaAppUITests.swift
//  MargaretkaAppUITests
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import XCTest

final class MargaretkaAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testOpenStatsView() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-tests")
        app.launch()

        let continueButton = app.buttons["ui_test_continue"].firstMatch
        if continueButton.waitForExistence(timeout: 10) {
            let dismissed = NSPredicate(format: "exists == false")
            let expectation = expectation(for: dismissed, evaluatedWith: continueButton)
            _ = XCTWaiter.wait(for: [expectation], timeout: 120)
        }

        let settingsButton = app.buttons["gear"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 4))
        settingsButton.tap()

        let statsElement = app.descendants(matching: .any)["settings_stats_link"].firstMatch
        if statsElement.waitForExistence(timeout: 4) {
            statsElement.tap()
        } else {
            let statsButton = app.buttons["Statystyki"].firstMatch
            XCTAssertTrue(statsButton.waitForExistence(timeout: 4))
            statsButton.tap()
        }

        XCTAssertTrue(app.scrollViews["stats_view"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
