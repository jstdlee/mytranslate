import XCTest

/// Drives the app with the demo engine (no network). Each step saves a numbered screenshot
/// into SCREENSHOT_DIR; CI publishes them to docs/gallery and the README.
final class SheetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testChipsRerunTheSheetInstantly() throws {
        let app = launch()
        app.buttons["open-sheet"].tap()

        // Opens with Translate; the English sample goes to Chinese.
        let result = app.staticTexts["result"]
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 简体中文"))

        app.buttons["lang-ja"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 日本語"))

        app.buttons["action-polish"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Polish → 日本語"))

        // Back to a chip that already ran: shown from the cache (unit tests check no second request).
        app.buttons["action-translate"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 日本語"))

        app.buttons["replace"].tap()
        XCTAssertFalse(app.buttons["replace"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textViews["try-text"].value as? String, "Demo · Translate → 日本語")
    }

    /// One pass through every screen and the main interactions, saving each state for the gallery.
    @MainActor
    func testGalleryTour() throws {
        let app = launch()
        screenshot(app, "01-try-it")

        app.buttons["open-sheet"].tap()
        let result = app.staticTexts["result"]
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 简体中文"))
        XCTAssertTrue(app.buttons["speak-source"].exists)
        XCTAssertTrue(app.buttons["speak-result"].exists)
        screenshot(app, "02-sheet-opens-auto-detected")

        // The source menu: Auto is the default; open it, then close it with "Detect language".
        app.buttons["source-menu"].tap()
        XCTAssertTrue(app.buttons["Detect language"].waitForExistence(timeout: 3))
        screenshot(app, "03-sheet-source-menu")
        app.buttons["Detect language"].tap()

        app.buttons["lang-ja"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Translate → 日本語"))
        screenshot(app, "04-sheet-language-switched")

        app.buttons["action-polish"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Polish → 日本語"))
        screenshot(app, "05-sheet-action-switched")

        let prompt = app.descendants(matching: .any)["quick-prompt"]
        prompt.tap()
        prompt.typeText("Make it friendlier")
        screenshot(app, "06-sheet-quick-prompt-typed")

        app.buttons["Run"].tap()
        XCTAssertTrue(waitForLabel(result, "Demo · Custom → 日本語"))
        screenshot(app, "07-sheet-quick-prompt-result")

        app.buttons["replace"].tap()
        XCTAssertTrue(app.textViews["try-text"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textViews["try-text"].value as? String, "Demo · Custom → 日本語")
        screenshot(app, "08-replaced-in-text")

        let tabs = ["Actions", "Settings", "Engine", "Set up"]
        for (index, tab) in tabs.enumerated() {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 3), tab)
            screenshot(app, "\(String(format: "%02d", 9 + index))-tab-\(tab.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        return app
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
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
