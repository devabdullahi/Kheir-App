import XCTest

/// The mushaf turns like an Arabic book: swiping left to right moves forward.
final class MushafUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSwipeRightTurnsToNextPage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting", "-mushafMode", "YES"]
        app.launch()
        let quranTab = app.buttons["Quran"].firstMatch
        XCTAssertTrue(quranTab.waitForExistence(timeout: 10))
        quranTab.tap()
        let fatihah = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1. '")).firstMatch
        XCTAssertTrue(fatihah.waitForExistence(timeout: 15))
        fatihah.tap()

        let opened = app.staticTexts["1 of 604"].waitForExistence(timeout: 20)
        XCTAssertTrue(opened)
        let page = app.otherElements["Page 1 of 604"]
        XCTAssertTrue(page.waitForExistence(timeout: 5))

        page.swipeRight()
        XCTAssertTrue(app.staticTexts["2 of 604"].waitForExistence(timeout: 5))

        app.otherElements["Page 2 of 604"].swipeLeft()
        XCTAssertTrue(app.staticTexts["1 of 604"].waitForExistence(timeout: 5))
    }
}
