//
//  ygocdbUITests.swift
//  ygocdbUITests
//
//  Created by hexzhou on 2026/1/11.
//

import XCTest

final class ygocdbUITests: XCTestCase {

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
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testSearchToolbarEntriesAreIndependent() throws {
        let app = XCUIApplication()
        app.launch()

        let limitListButton = app.buttons["禁卡表"]
        let preReleaseButton = app.buttons["先行卡"]
        XCTAssertTrue(limitListButton.waitForExistence(timeout: 5))
        XCTAssertTrue(preReleaseButton.exists)

        limitListButton.tap()
        XCTAssertTrue(app.navigationBars["禁卡表"].waitForExistence(timeout: 5))
        app.buttons["关闭"].tap()

        XCTAssertTrue(preReleaseButton.waitForExistence(timeout: 5))
        preReleaseButton.tap()
        XCTAssertTrue(app.navigationBars["先行卡"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
