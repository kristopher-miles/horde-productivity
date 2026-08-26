import XCTest

final class TheHordeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testFirstUsefulFlowAndGoalManagementAreReachable() throws {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        app.buttons["Add"].firstMatch.tap()
        let title = app.textFields["Goal title, required"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("UI product goal")
        app.navigationBars["Add Goal"].buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["UI product goal"].waitForExistence(timeout: 3))
        app.staticTexts["UI product goal"].tap()
        XCTAssertTrue(app.navigationBars["Goal Detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Complete Goal"].isHittable)
        XCTAssertTrue(app.buttons["Edit Future Goal"].exists)
        XCTAssertTrue(app.buttons["Archive"].exists)
        XCTAssertTrue(app.buttons["Delete Future Goal"].exists)
    }

    @MainActor func testGoalEditorShowsEveryPromisedOption() throws {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        app.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.switches["Add a date"].exists)
        app.buttons["Repeat & context"].tap()
        for label in ["Repeat", "Category", "Effort"] { XCTAssertTrue(app.staticTexts[label].exists, "Missing editor option: \(label)") }
        XCTAssertTrue(app.navigationBars["Add Goal"].buttons["Add"].exists)
    }

    @MainActor func testShowcaseCoversTodayDungeonChronicleAndSettings() throws {
        let app = launch(scenario: "showcase")
        for label in ["Story pending", "Overdue", "Due Today", "Upcoming"] {
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5), "Missing Today state: \(label)")
        }
        XCTAssertTrue(app.descendants(matching: .any)["DungeonScene.DungeonRecovery"].exists)
        keepScreenshot(of: app, name: "Today-showcase")
        app.staticTexts["Review the project plan"].tap()
        XCTAssertTrue(app.navigationBars["Goal Detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(containing: "Daily", in: app).exists)
        XCTAssertTrue(element(containing: "Work", in: app).exists)
        XCTAssertTrue(element(containing: "Medium", in: app).exists)
        app.navigationBars["Goal Detail"].buttons["Today"].tap()

        app.tabBars.buttons["Dungeon"].tap()
        XCTAssertTrue(app.navigationBars["Dungeon"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Morale"].exists)
        XCTAssertTrue(app.staticTexts["Residents"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Abilities"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ember Memory"].exists)

        app.tabBars.buttons["Chronicle"].tap()
        XCTAssertTrue(app.navigationBars["Chronicle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["The Lantern Ledger"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.searchFields["Search stories and goals"].exists)
        XCTAssertTrue(app.buttons["Filter"].exists)

        app.tabBars.buttons["Today"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        for label in ["Notifications", "Haptics", "Motion", "On-device model", "Prepare Export", "Reset Dungeon", "Delete All Local Data"] {
            if !app.staticTexts[label].exists && !app.buttons[label].exists && !app.switches[label].exists { app.swipeUp() }
            XCTAssertTrue(app.staticTexts[label].exists || app.buttons[label].exists || app.switches[label].exists, "Missing Settings feature: \(label)")
        }
    }

    @MainActor func testAuthoredNormalHazardAndRecoveryGraphics() throws {
        for (scenario, asset) in [("normal", "DungeonNormal"), ("hazard", "DungeonHazard"), ("recovery", "DungeonRecovery")] {
            let app = launch(scenario: scenario)
            app.tabBars.buttons["Dungeon"].tap()
            let scene = app.descendants(matching: .any)["DungeonScene.\(asset)"]
            XCTAssertTrue(scene.waitForExistence(timeout: 5), "Missing authored \(scenario) graphic")
            XCTAssertTrue(scene.label.contains("Ember"))
            XCTAssertTrue(scene.label.contains("3 kobolds"))
            keepScreenshot(of: app, name: "Dungeon-\(scenario)")
            app.terminate()
        }
    }

    @MainActor func testPositiveAndNegativeStoryConsequencesHaveDistinctVisualResponses() throws {
        let app = launch(scenario: "showcase")
        app.tabBars.buttons["Chronicle"].tap()
        app.staticTexts["The Lantern Ledger"].tap()
        XCTAssertTrue(app.navigationBars["Story Result"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["DungeonScene.DungeonRecovery"].exists)
        XCTAssertTrue(app.staticTexts["Completed goal"].exists)
        XCTAssertTrue(app.staticTexts["Morale: 59 → 63"].exists)
        keepScreenshot(of: app, name: "Consequence-positive")
        app.navigationBars["Story Result"].buttons["Chronicle"].tap()

        let search = app.searchFields["Search stories and goals"]
        search.tap()
        search.typeText("Rain at the Door")
        app.staticTexts["Rain at the Door"].tap()
        XCTAssertTrue(app.navigationBars["Story Result"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["DungeonScene.DungeonHazard"].exists)
        XCTAssertTrue(app.staticTexts["Expired goal"].exists)
        XCTAssertTrue(app.staticTexts["New thread: Damp Tool Rack"].exists)
        keepScreenshot(of: app, name: "Consequence-negative")
    }

    @MainActor func testEveryUnavailableCompatibilityStateHasFiniteGuidance() throws {
        let states = [("checking", "Checking this iPhone"), ("deviceNotEligible", "This iPhone isn’t supported"), ("intelligenceDisabled", "Turn on Apple Intelligence"), ("modelNotReady", "The on-device model isn’t ready"), ("unsupportedLocale", "This language isn’t supported"), ("unknown", "The model is unavailable")]
        for (state, title) in states {
            let app = XCUIApplication()
            app.launchEnvironment["HORDE_FORCE_COMPATIBILITY"] = state
            app.launch()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "Missing compatibility state: \(state)")
            if state == "checking" { XCTAssertTrue(app.activityIndicators.firstMatch.exists) }
            else { XCTAssertTrue(app.buttons["Check Again"].isHittable) }
            app.terminate()
        }
    }

    @MainActor func testInterruptedOnboardingAndLoadFailureHaveFinitePaths() throws {
        let onboarding = XCUIApplication()
        onboarding.launchEnvironment["HORDE_BYPASS_COMPATIBILITY"] = "1"
        onboarding.launchEnvironment["HORDE_RESET_UI_STATE"] = "1"
        onboarding.launchArguments += ["-onboardingStep", "1"]
        onboarding.launch()
        XCTAssertTrue(onboarding.staticTexts["Name your little world"].waitForExistence(timeout: 5))
        XCTAssertTrue(onboarding.textFields["Dragon name, optional"].exists)
        XCTAssertTrue(onboarding.buttons["Enter the Dungeon"].isHittable)
        onboarding.terminate()

        let failure = XCUIApplication()
        failure.launchEnvironment["HORDE_BYPASS_COMPATIBILITY"] = "1"
        failure.launchEnvironment["HORDE_RESET_UI_STATE"] = "1"
        failure.launchEnvironment["HORDE_FORCE_LOAD_FAILURE"] = "1"
        failure.launch()
        XCTAssertTrue(failure.staticTexts["Local data unavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(failure.buttons["Try Again"].isHittable)
    }

    @MainActor func testOneRealModelGoalToChronicleFlow() throws {
        let app = launch()
        app.buttons["Add"].firstMatch.tap()
        let title = app.textFields["Goal title, required"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("File the workshop notes")
        app.navigationBars["Add Goal"].buttons["Add"].tap()
        app.buttons["Complete File the workshop notes"].tap()
        XCTAssertTrue(app.navigationBars["Dungeon Consequence"].waitForExistence(timeout: 5))
        let committed = app.buttons["Continue"]
        let failed = app.staticTexts["No dungeon change was applied"]
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in committed.exists || failed.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 70), .completed)
        if failed.exists {
            app.buttons["Retry"].tap()
            XCTAssertTrue(committed.waitForExistence(timeout: 70))
        }
        committed.tap()
        app.tabBars.buttons["Chronicle"].tap()
        XCTAssertTrue(app.staticTexts["File the workshop notes"].waitForExistence(timeout: 5))
    }

    @MainActor private func launch(scenario: String? = nil, contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HORDE_BYPASS_COMPATIBILITY"] = "1"
        app.launchEnvironment["HORDE_AUTOMATE_ONBOARDING"] = "1"
        app.launchEnvironment["HORDE_RESET_UI_STATE"] = "1"
        if let scenario { app.launchEnvironment["HORDE_PRODUCT_SCENARIO"] = scenario }
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func keepScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func element(containing label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }
}
