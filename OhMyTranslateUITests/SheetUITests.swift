import XCTest

/// Drives the Try it sheet with the demo engine (no network) and saves screenshots.
final class SheetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testChipsRerunTheSheetInstantly() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()

        app.buttons["open-sheet"].tap()

        // Opens with Translate; the English sample goes to Chinese.
        let result = app.staticTexts["result"]
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 简体中文"))
        screenshot(app, "1-sheet-translate")

        app.buttons["lang-ja"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 日本語"))

        app.buttons["action-polish"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Polish → 日本語"))
        screenshot(app, "2-sheet-polish")

        // Back to a chip that already ran (from the cache; the unit tests check no second request).
        app.buttons["action-translate"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 日本語"))

        app.buttons["replace"].tap()
        XCTAssertFalse(app.buttons["replace"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textViews["try-text"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textViews["try-text"].value as? String, "Demo · Translate → 日本語")
    }

    @MainActor
    func testTabsOpen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        for tab in ["Actions", "Languages", "Engine", "Set up"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 3), tab)
            screenshot(app, "tab-\(tab)")
        }
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(device)-\(name).png"))
        }
    }
}
