//
//  RevengeUITests.swift
//  RevengeUITests
//
//  Created by Abdul on 2/4/26.
//

import XCTest

final class RevengeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 1. Splash → Home transition

    /// Verifies that the splash screen disappears and the Home tab bar item becomes
    /// hittable within a generous timeout that covers the 2.0 s delay + 0.5 s fade
    /// defined in SplashScreenView.
    @MainActor
    func testSplashTransitionsToHomeTab() throws {
        // The splash ZStack carries "splashScreen"; it should disappear after ~2.5 s.
        let splash = app.otherElements["splashScreen"]
        // We do NOT assert splash exists — it may be gone by the time the test runs.
        // What we care about is that the Home tab button appears and is hittable.
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(
            homeTab.waitForExistence(timeout: 8),
            "Home tab bar button should appear after splash dismisses"
        )
        XCTAssertTrue(homeTab.isHittable, "Home tab bar button should be hittable")
        // Suppress unused-variable warning; the assertion above is the real guard.
        _ = splash
    }

    // MARK: - 2. Countdown label on Home

    /// Asserts that the prayer-countdown label (identifier "prayerCountdown") is
    /// present on the Home screen within 10 s. The label will show "--:--:--" when
    /// location is unavailable, so any non-empty text is acceptable.
    @MainActor
    func testHomeDisplaysCountdown() throws {
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        homeTab.tap()

        let countdown = app.staticTexts["prayerCountdown"]
        XCTAssertTrue(
            countdown.waitForExistence(timeout: 10),
            "Prayer countdown label should appear on the Home screen"
        )
        XCTAssertFalse(
            countdown.label.isEmpty,
            "Prayer countdown label should not be empty"
        )
    }

    // MARK: - 3. Navigate to Settings

    /// From the Home screen, taps the gear-icon toolbar button (NavigationLink to
    /// SettingsView) and asserts that settingsScrollView and appearanceCard are visible.
    @MainActor
    func testNavigateToSettings() throws {
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        homeTab.tap()

        // The toolbar gear button carries no custom identifier; match by SF Symbol name
        // which XCTest exposes as the accessibility label set by SwiftUI.
        let gearButton = app.navigationBars.buttons["gearshape"]
            .exists
            ? app.navigationBars.buttons["gearshape"]
            : app.buttons["gearshape"]

        // Wait for the navigation bar to settle after splash.
        let navBarSettled = gearButton.waitForExistence(timeout: 5)
        if !navBarSettled {
            // Fallback: SwiftUI may render the button with a different description.
            // Try matching any button in the nav bar area.
            let anyNavButton = app.navigationBars.firstMatch.buttons.firstMatch
            XCTAssertTrue(anyNavButton.waitForExistence(timeout: 5), "Navigation bar button should exist")
            anyNavButton.tap()
        } else {
            gearButton.tap()
        }

        let scrollView = app.scrollViews["settingsScrollView"]
        XCTAssertTrue(
            scrollView.waitForExistence(timeout: 5),
            "settingsScrollView should appear after navigating to Settings"
        )

        let appearance = app.otherElements["appearanceCard"]
        XCTAssertTrue(
            appearance.waitForExistence(timeout: 5),
            "appearanceCard should be visible in Settings"
        )
    }

    // MARK: - 4. Theme picker exists in Settings

    /// Asserts that the segmented-control theme picker is present and hittable.
    /// Does NOT change the selection to avoid polluting subsequent tests.
    @MainActor
    func testThemePickerExistsInSettings() throws {
        try navigateToSettings()

        let picker = app.segmentedControls["themePicker"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "themePicker (segmented control) should exist in the Appearance card"
        )
        XCTAssertTrue(picker.isHittable, "themePicker should be hittable")
    }

    // MARK: - 5. Send Test Notification button exists in Settings

    /// Scrolls the Settings page to reveal the Notifications card and asserts
    /// that sendTestNotificationButton is present. Does NOT tap it.
    @MainActor
    func testSendTestNotificationButtonExistsInSettings() throws {
        try navigateToSettings()

        let button = app.buttons["sendTestNotificationButton"]

        // The button lives below the fold; scroll down until it appears.
        let scrollView = app.scrollViews["settingsScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        var found = button.waitForExistence(timeout: 2)
        if !found {
            scrollView.swipeUp()
            found = button.waitForExistence(timeout: 3)
        }

        XCTAssertTrue(found, "sendTestNotificationButton should exist in the Notifications card")
    }

    // MARK: - 6. Navigate to Bookmarks tab

    /// Taps the "Saved" tab bar button and asserts that the bookmarksView container
    /// exists. On a fresh install both sub-tabs are empty, so we also accept the
    /// bookmarksEmptyState element as evidence the view loaded.
    @MainActor
    func testNavigateToBookmarksTab() throws {
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        homeTab.tap()

        let savedTab = app.tabBars.buttons["Saved"]
        XCTAssertTrue(
            savedTab.waitForExistence(timeout: 5),
            "Saved (Bookmarks) tab bar button should exist"
        )
        savedTab.tap()

        let bookmarksRoot = app.otherElements["bookmarksView"]
        XCTAssertTrue(
            bookmarksRoot.waitForExistence(timeout: 5),
            "bookmarksView container should appear after tapping Saved tab"
        )

        // On a clean slate both tabs show empty-state; either is acceptable.
        let hasContent = app.otherElements["bookmarksEmptyState"].exists
            || app.collectionViews.firstMatch.exists
        XCTAssertTrue(
            hasContent,
            "Bookmarks screen should show either an empty-state view or a populated list"
        )
    }

    // MARK: - 7. Launch performance

    /// Measures cold-launch time using XCTApplicationLaunchMetric.
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Private helpers

    /// Navigates from the Home tab to the Settings screen via the gear toolbar button.
    /// Extracted to avoid repeating the 3-step preamble in every Settings test.
    private func navigateToSettings() throws {
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        homeTab.tap()

        // SwiftUI renders Image(systemName:) toolbar items with the SF Symbol name as
        // the accessibility identifier fallback. Try both common representations.
        let candidates: [XCUIElement] = [
            app.navigationBars.buttons["gearshape"],
            app.navigationBars.buttons["Settings"],
            app.buttons["gearshape"]
        ]

        var tapped = false
        for candidate in candidates {
            if candidate.waitForExistence(timeout: 3), candidate.isHittable {
                candidate.tap()
                tapped = true
                break
            }
        }

        if !tapped {
            // Last resort: tap the only button in the navigation bar trailing area.
            let trailingButton = app.navigationBars.firstMatch.buttons.element(boundBy: app.navigationBars.firstMatch.buttons.count - 1)
            XCTAssertTrue(trailingButton.waitForExistence(timeout: 3), "Could not locate Settings toolbar button")
            trailingButton.tap()
        }

        XCTAssertTrue(
            app.scrollViews["settingsScrollView"].waitForExistence(timeout: 5),
            "Settings screen should appear"
        )
    }
}
