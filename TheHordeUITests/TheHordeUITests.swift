import XCTest

final class TheHordeUITests: XCTestCase {
    @MainActor func testFiveOrderedAnimatedDragonStageFixture() throws {
        let app = XCUIApplication()
        app.launchEnvironment["HORDE_DRAGON_STAGE_FIXTURE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Dragon Stages"].waitForExistence(timeout: 5))
        for (rawValue, label) in [
            ("baby", "Baby"),
            ("adolescent", "Adolescent"),
            ("adult", "Adult"),
            ("elder", "Elder"),
            ("greatWyrm", "Great Wyrm")
        ] {
            XCTAssertTrue(app.otherElements["DragonStageFixture.\(rawValue)"].exists)
            XCTAssertTrue(app.staticTexts[label].exists)
        }
        XCTAssertEqual(app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "DragonStageFixture.")).count, 5)
    }

    private enum StoryResolutionID {
        static let state = "StoryResolution.State"
        static let suggestion = "StoryResolution.Suggestion"
        static let close = "StoryResolution.Close"
        static let customAction = "StoryResolution.CustomAction"
        static let customActionEntry = "StoryResolution.CustomActionEntry"
        static let backToSuggestion = "StoryResolution.BackToSuggestion"
        static let acceptSuggestion = "StoryResolution.AcceptSuggestion"
        static let commitFinalResolution = "StoryResolution.CommitFinalResolution"
    }

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
        app.staticTexts["UI product goal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Goal Detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Complete Goal"].isHittable)
        app.buttons["Goal.CancelOrFail"].tap()
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertTrue(app.buttons["Fail"].exists)
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
        XCTAssertTrue(app.descendants(matching: .any)["DungeonScene.DungeonStage1"].exists)
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
        XCTAssertTrue(app.staticTexts["Population"].exists)
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

    @MainActor func testCleanAndPopulatedWorldPresentationStates() throws {
        var app = launch(scenario: "normal")
        let population = app.staticTexts["Today.WorldPopulation"]
        XCTAssertTrue(population.waitForExistence(timeout: 5))
        XCTAssertEqual(population.label, "Ember is alone in Empty Cavern.")
        XCTAssertFalse(app.descendants(matching: .any)["Today.ActiveThread"].exists)
        app.tabBars.buttons["Dungeon"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Dungeon.Dragon"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Dungeon.Population.Empty"].exists)
        XCTAssertTrue(app.staticTexts["Empty Cavern"].exists)
        for hidden in ["Residents", "Discovered Places", "Facts", "Abilities", "Threats"] {
            XCTAssertFalse(app.staticTexts[hidden].exists, "Clean world showed empty \(hidden) section")
        }
        app.terminate()

        app = launch(scenario: "populated")
        XCTAssertTrue(app.descendants(matching: .any)["Today.ActiveThread"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["Today.WorldPopulation"].label, "Ember shares Empty Cavern with 1 kobold.")
        app.tabBars.buttons["Dungeon"].tap()
        for visible in ["Rill", "Echoing Depths", "The Wyrm Mark", "Ember Memory", "Stone Stalker"] {
            if !app.staticTexts[visible].exists { app.swipeUp() }
            XCTAssertTrue(app.staticTexts[visible].exists, "Populated world omitted \(visible)")
        }
    }

    @MainActor func testTransientScenariosPreserveTheCommittedRoomStage() throws {
        for scenario in ["normal", "hazard", "recovery"] {
            let app = launch(scenario: scenario)
            app.tabBars.buttons["Dungeon"].tap()
            let scene = app.descendants(matching: .any)["DungeonScene.DungeonStage1"]
            XCTAssertTrue(scene.waitForExistence(timeout: 5), "\(scenario) changed the committed room stage")
            XCTAssertTrue(scene.label.contains("Ember"))
            XCTAssertTrue(scene.label.contains("Ember is alone"))
            keepScreenshot(of: app, name: "Dungeon-\(scenario)")
            app.terminate()
        }
    }

    @MainActor func testStoryCuesPreserveTheRecordedRoomStage() throws {
        let app = launch(scenario: "showcase")
        app.tabBars.buttons["Chronicle"].tap()
        app.staticTexts["The Lantern Ledger"].tap()
        XCTAssertTrue(app.navigationBars["Story Result"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["DungeonScene.DungeonStage1"].exists)
        XCTAssertTrue(app.staticTexts["Completed goal"].exists)
        XCTAssertTrue(app.staticTexts["Morale: 59 → 63"].exists)
        keepScreenshot(of: app, name: "Consequence-positive")
        app.navigationBars["Story Result"].buttons["Chronicle"].tap()

        let search = app.searchFields["Search stories and goals"]
        search.tap()
        search.typeText("Rain at the Door")
        app.staticTexts["Rain at the Door"].tap()
        XCTAssertTrue(app.navigationBars["Story Result"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["DungeonScene.DungeonStage1"].exists)
        XCTAssertTrue(app.staticTexts["Expired goal"].exists)
        XCTAssertTrue(app.staticTexts["New thread: Flooded Threshold"].exists)
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
        XCTAssertTrue(onboarding.staticTexts["Name your dragon and dungeon"].waitForExistence(timeout: 5))
        XCTAssertTrue(onboarding.textFields["Dragon name, optional"].exists)
        let enter = onboarding.buttons["Enter the Dungeon"]
        if !enter.isHittable { onboarding.swipeUp() }
        XCTAssertTrue(enter.isHittable)
        onboarding.terminate()

        let failure = XCUIApplication()
        failure.launchEnvironment["HORDE_BYPASS_COMPATIBILITY"] = "1"
        failure.launchEnvironment["HORDE_RESET_UI_STATE"] = "1"
        failure.launchEnvironment["HORDE_FORCE_LOAD_FAILURE"] = "1"
        failure.launch()
        XCTAssertTrue(failure.staticTexts["Local data unavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(failure.buttons["Try Again"].isHittable)
    }

    @MainActor func testOnboardingShowsTheEmptyCavernAndUpdatesTheExactNarrative() throws {
        let app = XCUIApplication()
        app.launchEnvironment["HORDE_BYPASS_COMPATIBILITY"] = "1"
        app.launchEnvironment["HORDE_RESET_UI_STATE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["A Young Dragon, Alone"].waitForExistence(timeout: 5))
        let premise = app.descendants(matching: .any)["Onboarding.EmptyCavernPremise"]
        XCTAssertEqual(premise.label, "Your young dragon begins alone in a dirty, cold, unruly, and dangerous empty cavern—with no residents, no comforts, and no furnished home.")
        let narrative = app.descendants(matching: .any)["Onboarding.OriginNarrative"]
        XCTAssertEqual(narrative.label, "Ember has recently left the nest and searched for their own lair. After flying far from home, they arrived at an empty cavern extending deep into the rock. They are small now, but they will grow. They settle onto the cold stone, and plan for what's next.")
        let scene = app.descendants(matching: .any)["DungeonScene.DungeonStage1"]
        XCTAssertTrue(scene.label.contains("Ember is alone"))
        XCTAssertFalse(scene.label.localizedCaseInsensitiveContains("kobold"))

        let continueButton = app.buttons["Continue"]
        if !continueButton.isHittable { app.swipeUp() }
        continueButton.tap()
        XCTAssertTrue(app.staticTexts["Name your dragon and dungeon"].waitForExistence(timeout: 3))
        let name = app.textFields["Dragon name, optional"]
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
        name.typeText("Vesper")
        let updatedNarrative = "Vesper has recently left the nest and searched for their own lair. After flying far from home, they arrived at an empty cavern extending deep into the rock. They are small now, but they will grow. They settle onto the cold stone, and plan for what's next."
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", updatedNarrative), object: narrative)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)

        app.keyboards.buttons["return"].tap()
        app.swipeUp()
        let azure = app.buttons["Onboarding.Color.azure"]
        if !azure.isHittable { app.swipeUp() }
        XCTAssertTrue(azure.waitForExistence(timeout: 3))
        azure.tap()
        XCTAssertEqual(azure.value as? String, "Selected")
        XCTAssertTrue(app.descendants(matching: .any)["Onboarding.CustomDragonColor"].waitForExistence(timeout: 3))
    }

    @MainActor func testExplicitAcceptanceGatePreservesVisibleStateUntilAcceptance() throws {
        let app = XCUIApplication()
        app.launchEnvironment["HORDE_BYPASS_COMPATIBILITY"] = "1"
        app.launchEnvironment["HORDE_AUTOMATE_ONBOARDING"] = "1"
        app.launchEnvironment["HORDE_RESET_UI_STATE"] = "1"
        app.launchEnvironment["HORDE_RF08_UI_FIXTURE"] = "1"
        app.launch()

        let state = app.descendants(matching: .any)[StoryResolutionID.state]
        let suggestion = app.staticTexts[StoryResolutionID.suggestion]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        let baseline = try XCTUnwrap(state.value as? String)
        XCTAssertTrue(baseline.contains("Chronicle entries 0"))
        XCTAssertTrue(baseline.contains("Accepted action none"))

        app.buttons[StoryResolutionID.close].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Chronicle"].tap()
        XCTAssertTrue(app.staticTexts["No tales yet"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Today"].tap()
        element(containing: "Story pending", in: app).tap()
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3))
        XCTAssertEqual(state.value as? String, baseline)

        app.buttons[StoryResolutionID.customAction].tap()
        let editor = app.textViews[StoryResolutionID.customActionEntry]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText("Circle the vault at dawn")
        app.buttons[StoryResolutionID.backToSuggestion].tap()
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3))
        XCTAssertEqual(state.value as? String, baseline)

        app.buttons[StoryResolutionID.acceptSuggestion].tap()
        XCTAssertTrue(app.staticTexts["Final narration"].waitForExistence(timeout: 10))
        let accepted = try XCTUnwrap(state.value as? String)
        XCTAssertTrue(accepted.contains("Dungeon revision 0"))
        XCTAssertTrue(accepted.contains("Chronicle entries 0"))
        XCTAssertTrue(accepted.contains("Accepted action Guard the ember vault"))
        XCTAssertTrue(app.buttons[StoryResolutionID.commitFinalResolution].exists)

        app.buttons[StoryResolutionID.close].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Chronicle"].tap()
        XCTAssertTrue(app.staticTexts["No tales yet"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Today"].tap()
        element(containing: "Story pending", in: app).tap()
        XCTAssertTrue(app.staticTexts["Final narration"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons[StoryResolutionID.commitFinalResolution].exists)
        XCTAssertEqual(state.value as? String, accepted)
    }

    @MainActor func testOneRealModelGoalReachesExplicitActionReview() throws {
        let app = launch()
        app.buttons["Add"].firstMatch.tap()
        let title = app.textFields["Goal title, required"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("File the workshop notes")
        app.navigationBars["Add Goal"].buttons["Add"].tap()
        app.buttons["Complete File the workshop notes"].tap()
        XCTAssertTrue(app.navigationBars["Choose an Action"].waitForExistence(timeout: 5))
        let suggestion = app.buttons[StoryResolutionID.acceptSuggestion]
        let failed = app.staticTexts["No dungeon change was applied"]
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in suggestion.exists || failed.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 70), .completed)
        if failed.exists {
            app.buttons["Retry"].tap()
            XCTAssertTrue(suggestion.waitForExistence(timeout: 70))
        }
        XCTAssertTrue(app.buttons[StoryResolutionID.customAction].exists)
        XCTAssertTrue(app.buttons[StoryResolutionID.close].exists)
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
