import XCTest

final class CaelynUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Decline Apple's Health Access sheet, whatever iOS is calling the button
    /// this year.
    ///
    /// The identifier is NOT stable across releases: this suite looked for
    /// `UIA.Health.DoNotAllow.Button`, while iOS 18 ships
    /// `UIA.Health.AuthSheet.CancelButton` labelled "Don't Allow" (with a curly
    /// apostrophe). The tap therefore never landed, the sheet stayed open for
    /// the whole timeout, and the test failed claiming onboarding had not
    /// advanced — when in truth nobody had answered the sheet. A guard that
    /// fails for its own reasons is worse than no guard, because the next
    /// person reads the failure as the app being broken.
    ///
    /// Returns true if the sheet was found and dismissed.
    @discardableResult
    func declineHealthAccessSheet(in app: XCUIApplication, timeout: TimeInterval = 8) -> Bool {
        let candidates = [
            app.buttons["UIA.Health.AuthSheet.CancelButton"],
            app.buttons["UIA.Health.DoNotAllow.Button"],
        ]
        var sheetButton: XCUIElement?
        for candidate in candidates where candidate.waitForExistence(timeout: timeout / TimeInterval(candidates.count)) {
            sheetButton = candidate
            break
        }
        // Last resort: match the visible label, both apostrophe forms.
        if sheetButton == nil {
            for label in ["Don\u{2019}t Allow", "Don't Allow"] {
                let byLabel = app.buttons[label]
                if byLabel.waitForExistence(timeout: 2) { sheetButton = byLabel; break }
            }
        }
        // iOS 27 moved the choice to the foot of a three-page list of categories,
        // as a text cell rather than a button, with nothing in the nav bar. Scroll
        // to it — it is not hittable until it is on screen.
        if sheetButton == nil, app.navigationBars["Health Access"].exists {
            for label in ["Don\u{2019}t Allow", "Don't Allow"] {
                let cell = app.staticTexts[label]
                guard cell.exists else { continue }
                for _ in 0..<12 where !cell.isHittable {
                    app.swipeUp(velocity: .fast)
                }
                if cell.isHittable { sheetButton = cell; break }
            }
        }
        guard let button = sheetButton else { return false }
        button.tap()

        // Apple follows a decline with its own alert ("You can turn on health
        // data categories later in the Health app."). requestAuthorization does
        // not return until it is dismissed. Note that Apple says this itself —
        // which is exactly why Caelyn must not repeat the instruction.
        let ok = app.buttons["OK"]
        if ok.waitForExistence(timeout: 5) { ok.tap() }
        return true
    }

    /// Dismiss the one-time account offer if it is up.
    ///
    /// It presents over the home screen the first time someone arrives there,
    /// which is correct product behaviour and therefore genuinely part of the
    /// journey these tests walk. Declining is the path taken by someone who just
    /// wants to use the app, so that is the path asserted here.
    /// Decline iOS's notification permission alert, if it appears.
    ///
    /// It belongs to SpringBoard, not to Caelyn, so it cannot be reached through
    /// `app.alerts` — the query has to address SpringBoard directly. The simulator
    /// often never shows it at all, which is why this suite ran green there while
    /// blocking on a real device at the reminders step.
    ///
    /// Declining is deliberate: onboarding must continue identically either way,
    /// and it leaves the test device's own settings untouched.
    @discardableResult
    func declineNotificationsAlert(timeout: TimeInterval = 8) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Don\u{2019}t Allow", "Don't Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: timeout / 2) {
                button.tap()
                return true
            }
        }
        return false
    }

    @discardableResult
    func dismissAccountOfferIfPresent(in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        let notNow = app.buttons["UIA.AccountOffer.NotNow"]
        guard notNow.waitForExistence(timeout: timeout) else { return false }
        notNow.tap()
        return true
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        let onboardingHero = app.staticTexts["Meet Caelyn"]
        let mainHomeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(
            onboardingHero.waitForExistence(timeout: 5) || mainHomeTab.waitForExistence(timeout: 5),
            "Expected either onboarding welcome (first launch) or main tab bar (already onboarded) to appear."
        )
    }

    /// A lock setting that outlives its profile must not put Face ID up over
    /// onboarding — there is nothing to unlock. Found on a device, where an
    /// interrupted run left App Lock on and "Meet Caelyn" arrived under a Face ID
    /// sheet. The flag is forced through the arguments domain.
    func testOnboardingIsNeverCoveredByAnUnlockPrompt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-onboarding", "-caelyn.lock.enabled", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Meet Caelyn"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let authSheet = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Cancel' OR label CONTAINS[c] 'Face ID'")).firstMatch
        XCTAssertFalse(authSheet.exists, "an unlock prompt covered onboarding, with nothing to unlock")
        XCTAssertTrue(app.buttons["Let's begin"].isHittable)
        capture("Onboarding-No-Unlock-Prompt", app: app)
    }

    func testOnboardingPrimaryActionsAreReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-test-onboarding",
            "-caelyn.seenIntro.home", "NO",
            "-caelyn.seenIntro.calendar", "NO",
            "-caelyn.seenIntro.log", "NO",
            "-caelyn.seenIntro.insights", "NO"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Meet Caelyn"].waitForExistence(timeout: 5))
        tapButton("Let's begin", in: app)

        XCTAssertTrue(app.staticTexts["A simple daily rhythm"].waitForExistence(timeout: 5))
        capture("Onboarding-Workflow", app: app)
        tapButton("Set up my cycle", in: app)

        XCTAssertTrue(app.staticTexts["Private by design 🔒"].waitForExistence(timeout: 5))
        tapButton("I understand, continue", in: app)

        XCTAssertTrue(app.staticTexts["When did your last period start?"].waitForExistence(timeout: 5))
        tapButton("Continue", in: app)

        XCTAssertTrue(app.staticTexts["How long is your usual cycle?"].waitForExistence(timeout: 5))
        tapButton("Continue", in: app)

        XCTAssertTrue(app.staticTexts["How long does your period usually last?"].waitForExistence(timeout: 5))
        let twelveDays = app.buttons["12 days"]
        for _ in 0..<4 where !twelveDays.isHittable { app.swipeUp() }
        XCTAssertTrue(twelveDays.isHittable, "Every period-length choice should be reachable.")
        XCTAssertGreaterThanOrEqual(twelveDays.frame.width, 44)
        XCTAssertGreaterThanOrEqual(twelveDays.frame.height, 44)
        capture("Onboarding-Period-Length", app: app)
        tapButton("Continue", in: app)

        XCTAssertTrue(app.staticTexts["What matters to you?"].waitForExistence(timeout: 5))
        tapButton("Looks good!", in: app)

        // App Review 5.1.1(iv): a single neutrally-labelled button that opens the
        // system sheet, no grant-worded control, and no skip. Declining in Apple's
        // sheet must still advance — that is the regression this guards.
        if app.staticTexts["Import from Apple Health"].waitForExistence(timeout: 2) {
            XCTAssertFalse(app.buttons["Skip for now"].exists,
                           "The Health step must not frame declining as skipping.")
            XCTAssertFalse(app.buttons["Connect Apple Health"].exists,
                           "The button leading to the permission sheet must be neutrally labelled.")
            capture("Onboarding-Apple-Health", app: app)
            tapButton("Continue", in: app)

            // Continue must open Apple's own Health Access sheet — that is the
            // whole point of the 5.1.1(iv) fix. The sheet is a remote view inside
            // the app's element tree, so it is driven directly rather than by an
            // interruption monitor.
            // On a genuinely fresh device this opens Apple's Health Access sheet.
            // HealthKit remembers the answer for the lifetime of the install, so on
            // a re-run the sheet is skipped — hence best-effort rather than an
            // assertion. The assertion that matters is that onboarding advances.
            declineHealthAccessSheet(in: app)
        }

        // Declining Health must not block anything — this is the regression guard
        // for the 5.1.1(iv) rejections.
        XCTAssertTrue(app.staticTexts["Gentle reminders 🔔"].waitForExistence(timeout: 10),
                      "Declining Apple Health must still advance onboarding.")
        tapButton("Continue", in: app)

        // On a real device iOS asks about notifications here and blocks until
        // answered. Declining must not stop onboarding.
        declineNotificationsAlert()

        XCTAssertTrue(app.staticTexts["Keep Caelyn private 🔐"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Skip for now"].exists,
                       "The lock step must not frame declining as skipping.")
        tapButton("Continue", in: app)

        XCTAssertTrue(app.staticTexts["You're all set! 🎉"].waitForExistence(timeout: 5))
        tapButton("Open Caelyn", in: app)

        // Straight out of onboarding she is offered an account. Declining it is
        // an answer, and the app behind it must be fully usable immediately.
        XCTAssertTrue(dismissAccountOfferIfPresent(in: app),
                      "The account offer should greet someone who has just onboarded.")

        XCTAssertTrue(app.staticTexts["Your daily snapshot"].waitForExistence(timeout: 5))
        capture("First-Use-Home", app: app)

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Using the calendar"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Log"].tap()
        XCTAssertTrue(app.staticTexts["Logging is flexible"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Patterns take time"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        let guideButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "How Caelyn works")
        ).firstMatch
        for _ in 0..<16 where !guideButton.isHittable { app.swipeUp() }
        XCTAssertTrue(guideButton.isHittable, "The permanent in-app guide should be reachable from Settings.")
        guideButton.tap()
        XCTAssertTrue(app.staticTexts["Small logs become a clearer picture"].waitForExistence(timeout: 5))
        capture("In-App-Guide", app: app)
    }

    /// Exercises the same path a returning user takes in ordinary use: act from
    /// Home, record a detailed check-in, confirm Calendar sees it, then confirm
    /// Insights still renders from the updated history.
    func testReturningUserDailyJourneyPersistsAcrossTabs() throws {
        let app = launchSeeded()

        // Home quick actions: the one-tap period action mutates immediately; the
        // other three all open the full editor and must remain understandable.
        let logPeriod = app.buttons["Log Period"]
        reveal(logPeriod, in: app)
        logPeriod.tap()
        XCTAssertTrue(app.staticTexts["Period logged"].waitForExistence(timeout: 3))

        for action in ["Symptoms", "Mood", "Note"] {
            let button = app.buttons[action]
            reveal(button, in: app)
            button.tap()
            XCTAssertTrue(app.navigationBars["Today's Log"].waitForExistence(timeout: 3), "\(action) should open today's editor")
            app.navigationBars["Today's Log"].buttons["Done"].tap()
        }

        tapTab("Log", in: app)
        // The header reads "Today's check-in \u{00B7} Cycle day N", so match the prefix.
        // An exact-string query could never match, whatever the app did.
        let checkInHeader = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Today's check-in")
        ).firstMatch
        XCTAssertTrue(checkInHeader.waitForExistence(timeout: 3),
                      "The Log tab should show today's check-in header.")

        let heavyFlow = app.buttons["Heavy flow"]
        reveal(heavyFlow, in: app)
        heavyFlow.tap()
        XCTAssertTrue(heavyFlow.isSelected)

        let pain = app.sliders["Pain level"]
        reveal(pain, in: app)
        pain.adjust(toNormalizedSliderPosition: 0.6)
        // A drag lands within a point or two of the target on real hardware, where
        // the simulator hits it exactly. Assert the band the gesture means, not a
        // single value the device cannot promise.
        // The value reads like Optional("7/10"), so take the first run of digits —
        // filtering every digit out of the whole string yields "710".
        let painRaw = String(describing: pain.value)
        let painValue = Int(painRaw.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })) ?? -1
        XCTAssertTrue((5...7).contains(painValue),
                      "Pain should land near 6/10 after dragging to 60%, got \(painValue)")

        let painLocation = app.buttons["Pelvic pain pain location"]
        reveal(painLocation, in: app)
        painLocation.tap()
        XCTAssertTrue(painLocation.isSelected)

        let fatigue = app.buttons["Fatigue"]
        reveal(fatigue, in: app)
        fatigue.tap()
        XCTAssertTrue(fatigue.isSelected)
        let severeFatigue = app.buttons["Severe severity for Fatigue"]
        reveal(severeFatigue, in: app)
        severeFatigue.tap()
        XCTAssertTrue(severeFatigue.isSelected)

        let addSymptom = app.buttons["Add custom symptom"]
        reveal(addSymptom, in: app)
        addSymptom.tap()
        XCTAssertTrue(app.navigationBars["Add Symptom"].waitForExistence(timeout: 3))
        let symptomName = app.textFields["e.g. Insomnia, Joint pain"]
        symptomName.tap()
        symptomName.typeText("Joint stiffness")
        app.navigationBars["Add Symptom"].buttons["Add"].tap()
        let customSymptom = app.buttons["Joint stiffness"]
        reveal(customSymptom, in: app)
        customSymptom.tap()
        XCTAssertTrue(customSymptom.isSelected)

        let calm = app.buttons["Calm mood"]
        reveal(calm, in: app)
        calm.tap()
        XCTAssertTrue(calm.isSelected)

        let highEnergy = app.buttons["High energy"]
        reveal(highEnergy, in: app)
        highEnergy.tap()
        XCTAssertTrue(highEnergy.isSelected)

        let temperature = app.textFields["Basal body temperature in degrees Celsius"]
        reveal(temperature, in: app)
        temperature.tap()
        temperature.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        temperature.typeText("36.55")

        let negativeTest = app.buttons["Negative ovulation test"]
        reveal(negativeTest, in: app)
        negativeTest.tap()
        XCTAssertTrue(negativeTest.isSelected)

        let advanced = app.buttons["More to track · meds, fluid, tests"]
        reveal(advanced, in: app)
        advanced.tap()

        let medication = app.textFields["What are you taking today?"]
        reveal(medication, in: app)
        medication.tap()
        medication.typeText("Magnesium")
        medication.typeText(XCUIKeyboardKey.return.rawValue)

        let pregnancyTest = app.switches["Pregnancy test"]
        reveal(pregnancyTest, in: app)
        pregnancyTest.tap()
        XCTAssertEqual(pregnancyTest.value as? String, "1")
        let sexualActivity = app.switches["Sexual activity"]
        sexualActivity.tap()
        XCTAssertEqual(sexualActivity.value as? String, "1")

        let cervicalFluid = app.buttons["Cervical fluid"]
        reveal(cervicalFluid, in: app)
        cervicalFluid.tap()
        app.buttons["Dry"].tap()
        XCTAssertEqual(cervicalFluid.value as? String, "Dry")

        let note = app.textViews["Private note"]
        reveal(note, in: app)
        note.tap()
        note.typeText(" Simulator real-world check.")

        // KNOWN FAILURE, pre-existing and not a product defect.
        //
        // The note is deliberately still focused here: committing focused text on
        // the way out is the behaviour this journey tests. But the software
        // keyboard overlays the top of the tab bar (keyboard ends at y=874, the
        // tab bar starts at y=849), so every tab button reports isHittable ==
        // false and the switch never happens. Verified by dumping the tree at the
        // failure: tabs=["Home:false", "Calendar:false", "Log:true", ...].
        //
        // Tried and rejected: app.swipeDown(); a slow swipe on
        // app.scrollViews.firstMatch (there are three, and firstMatch is not the
        // one LogView's .scrollDismissesKeyboard(.interactively) governs); an
        // explicit press-and-drag confined to the area above the keyboard; and a
        // coordinate tap low inside the tab button, below the keyboard's frame.
        // The keyboard survives all four, on iPhone 15 Pro and 15 Pro Max alike.
        //
        // The fix belongs in the app or in this journey's structure — an explicit
        // way to put the keyboard away — not in another gesture. Note also that
        // the nav bar's label is empty here, so the assertion below is a second
        // thing to revisit.
        tapTab("Calendar", in: app)
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        let todayCell = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", ", today")).firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 3))
        todayCell.tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
        let calendarHeavy = app.buttons["Heavy flow"]
        XCTAssertTrue(calendarHeavy.waitForExistence(timeout: 3))
        XCTAssertTrue(calendarHeavy.isSelected, "Calendar should show the flow edited in Log")
        app.buttons["Light flow"].tap()
        let closeDay = app.navigationBars.buttons["Done"]
        closeDay.tap()
        XCTAssertTrue(closeDay.waitForNonExistence(timeout: 4))

        // Month movement and the Today shortcut are core calendar navigation.
        let previousMonth = app.buttons["Previous month"]
        XCTAssertTrue(previousMonth.waitForExistence(timeout: 3))
        previousMonth.tap()
        let calendarToday = app.navigationBars["Calendar"].buttons["Today"]
        XCTAssertTrue(calendarToday.waitForExistence(timeout: 5))
        calendarToday.tap()

        tapTab("Log", in: app)
        let persistedLight = app.buttons["Light flow"]
        revealFromBottom(persistedLight, in: app)
        XCTAssertTrue(persistedLight.isSelected, "Calendar edits should persist back to Log")

        tapTab("Insights", in: app)
        XCTAssertTrue(app.staticTexts["Patterns"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["What Caelyn learned about you"].exists)
        let insightsScroll = app.scrollViews.firstMatch
        for _ in 0..<5 { insightsScroll.swipeUp() }
        XCTAssertTrue(
            app.staticTexts["Cycle History"].exists || app.staticTexts["Cycle summary"].exists || app.staticTexts["Basal body temperature"].exists,
            "A populated user's deeper insights should remain reachable"
        )
        capture("Simulator-Daily-Journey-Insights", app: app)
    }

    /// Guards the screen App Review screenshotted for guideline 5.1.1(iv): the
    /// control that opens the HealthKit sheet must be neutrally labelled, and
    /// nothing on the screen — before or after the user declines — may direct
    /// them to go and grant access.
    func testHealthSettingsNeverDirectsUserToGrantAccess() throws {
        let app = launchSeeded()
        tapTab("Settings", in: app)
        openSetting("Apple Health", in: app, expects: "Apple Health")

        XCTAssertTrue(app.staticTexts["Sync with Apple Health"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["Connect Apple Health"].exists,
                       "The control opening the permission sheet must be neutrally labelled.")
        XCTAssertTrue(app.buttons["Continue"].exists, "Expected a neutral Continue button.")
        capture("Health-Settings-Before", app: app)

        app.buttons["Continue"].tap()

        declineHealthAccessSheet(in: app)
        sleep(2)
        capture("Health-Settings-AfterDecline", app: app)

        // The wording that got build 9 rejected, in the state nobody had opened.
        for banned in ["Apple Health access was denied. Enable it in iOS Settings → Privacy & Security → Health.",
                       "Enable access in iOS Settings → Health anytime."] {
            XCTAssertFalse(app.staticTexts[banned].exists,
                           "Declining must not produce copy directing the user to grant access: \(banned)")
        }
    }

    /// The guided import flow, as far as it can be driven without a real file:
    /// the source picker, one app's instructions, and the route to the file
    /// browser. Every control it checks is one a VoiceOver user has to be able
    /// to reach by name.
    func testBringHistoryFlowIsReachableAndLabelled() throws {
        let app = launchSeeded()
        tapTab("Settings", in: app)

        let entry = settingButton("Bring your history", in: app)
        reveal(entry, in: app)
        entry.tap()

        XCTAssertTrue(app.staticTexts["You don't have to start over"].waitForExistence(timeout: 4))
        for source in ["apple-health", "clue", "flo", "period-tracker", "another-app", "caelyn-backup"] {
            XCTAssertTrue(app.buttons["UIA.Import.Source.\(source)"].exists,
                          "Missing source row: \(source)")
        }

        // Clue leads to instructions, not straight into a file browser — the
        // export has to be requested from Clue first, and she needs telling.
        app.buttons["UIA.Import.Source.clue"].tap()
        let chooseFile = app.buttons["UIA.Import.ChooseFile"]
        XCTAssertTrue(chooseFile.waitForExistence(timeout: 4), "Clue should explain how to get the file")
        XCTAssertTrue(app.staticTexts["Request data"].exists || app.descendants(matching: .any)
            .containing(NSPredicate(format: "label CONTAINS[c] 'Request data'")).count > 0,
                      "the instructions should name the button she has to find in Clue")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["UIA.Import.Source.clue"].waitForExistence(timeout: 4),
                      "Back should return to the source picker")
        app.buttons["UIA.Import.Close"].tap()
    }

    /// Opens and operates each user-facing Settings destination that can run
    /// without a physical sensor or an external account.
    func testSettingsAndDataToolsJourney() throws {
        let app = launchSeeded()
        tapTab("Settings", in: app)

        openSetting("Cycle & period length", in: app, expects: "Cycle settings")
        XCTAssertTrue(app.staticTexts["CYCLE LENGTH"].waitForExistence(timeout: 3))
        sleep(2)
        let cycle27 = app.buttons["27 day cycle"]
        XCTAssertTrue(cycle27.waitForExistence(timeout: 3))
        XCTAssertTrue(cycle27.isHittable)
        cycle27.tap()
        let period6 = app.buttons["6 day period"]
        reveal(period6, in: app)
        period6.tap()
        XCTAssertTrue(app.staticTexts["6"].waitForExistence(timeout: 3))
        app.navigationBars["Cycle settings"].buttons["Done"].tap()
        XCTAssertTrue(settingButton("Cycle & period length", in: app).label.contains("27-day cycle · 6-day period"))

        openSetting("Your privacy", in: app, expects: "Your Privacy")
        XCTAssertTrue(app.staticTexts["Private by architecture,\nnot policy."].exists)
        backToSettings(from: "Your Privacy", in: app)

        openSetting("Apple Health", in: app, expects: "Apple Health")
        XCTAssertTrue(app.staticTexts["Sync with Apple Health"].exists)
        // Nothing is connected in the simulator, so this is the disconnected
        // state: an explanation plus one neutrally-worded way in. The per-type
        // toggles only exist after connecting.
        //
        // This deliberately no longer asserts "Menstrual flow", "Symptoms and
        // pain" and "Wrist temperature". Those were removed on purpose: App
        // Review 5.1.1(iv) rejected the screen for replicating Apple's own
        // permission list, so asserting them would pin the app to the very
        // content it was made to delete.
        XCTAssertTrue(app.buttons["Continue"].exists || app.buttons["Unavailable on this device"].exists,
                      "The disconnected state should offer a neutrally-worded way in.")
        backToSettings(from: "Apple Health", in: app)

        openSetting("Backup", in: app, expects: "Backup")
        XCTAssertTrue(app.staticTexts["Your data lives here.\nNowhere else."].exists)
        XCTAssertTrue(app.staticTexts["Stored on this device"].exists)
        backToSettings(from: "Backup", in: app)

        let export = settingButton("Export data", in: app)
        reveal(export, in: app)
        export.tap()
        XCTAssertTrue(app.navigationBars["Export data"].waitForExistence(timeout: 3))
        app.buttons["All time"].tap()
        app.buttons["PDF"].tap()
        let generatePDF = app.buttons["Generate PDF"]
        reveal(generatePDF, in: app)
        generatePDF.tap()
        XCTAssertTrue(app.buttons["Share PDF"].waitForExistence(timeout: 8), "PDF export should generate in the app")
        app.buttons["CSV"].tap()
        let generateCSV = app.buttons["Generate CSV"]
        reveal(generateCSV, in: app)
        generateCSV.tap()
        XCTAssertTrue(app.buttons["Share CSV"].waitForExistence(timeout: 8), "CSV export should generate in the app")
        let closeExport = app.navigationBars["Export data"].buttons["Done"]
        closeExport.tap()
        XCTAssertTrue(closeExport.waitForNonExistence(timeout: 4))

        // The row now opens the guided "Bring your history" flow rather than
        // dropping straight into the system file browser.
        let importer = settingButton("Bring your history", in: app)
        reveal(importer, in: app)
        importer.tap()
        XCTAssertTrue(app.staticTexts["You don't have to start over"].waitForExistence(timeout: 4),
                      "Bring your history should open the source picker")
        XCTAssertTrue(app.buttons["UIA.Import.Source.apple-health"].exists)
        XCTAssertTrue(app.buttons["UIA.Import.Source.clue"].exists)
        XCTAssertTrue(app.buttons["UIA.Import.Source.flo"].exists)
        XCTAssertTrue(app.buttons["UIA.Import.Source.period-tracker"].exists)
        // Nothing unverified may be advertised as a supported app. Natural Cycles
        // is deliberately not on this list any more: 1.2 gave it a real, verified
        // Apple Health route, so its name appearing here is correct. Ovia and
        // Stardust have no verified route of any kind and must never appear.
        XCTAssertFalse(app.staticTexts["Ovia"].exists)
        XCTAssertFalse(app.staticTexts["Stardust"].exists)
        app.buttons["UIA.Import.Close"].tap()
        let cancelImport = app.buttons["Cancel"]
        if cancelImport.waitForExistence(timeout: 2) { cancelImport.tap() }

        let firstDay = settingButton("First day of week", in: app)
        reveal(firstDay, in: app)
        firstDay.tap()
        XCTAssertTrue(app.navigationBars["Start of week"].waitForExistence(timeout: 3))
        app.buttons["Monday"].tap()
        XCTAssertTrue(settingButton("First day of week", in: app).label.contains("Monday"))

        let appearance = settingButton("Appearance", in: app)
        reveal(appearance, in: app)
        appearance.tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 3))
        app.buttons["Dark"].tap()
        let darkAppearance = settingButton("Appearance", in: app)
        XCTAssertTrue(darkAppearance.label.contains("Dark"))
        darkAppearance.tap()
        app.buttons["System"].tap()

        openSetting("Birth Control", in: app, expects: "Birth Control")
        sleep(1)
        let birthControlMode = app.switches["Birth Control Mode"]
        XCTAssertTrue(birthControlMode.isHittable)
        birthControlMode.tap()
        if birthControlMode.value as? String != "1" {
            birthControlMode.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(birthControlMode.value as? String, "1")
        let patch = app.buttons["Patch"]
        XCTAssertTrue(patch.waitForExistence(timeout: 4), "Enabling Birth Control Mode should reveal method choices")
        sleep(1)
        patch.tap()
        let firstPatchDate = app.staticTexts["First patch date"]
        if !firstPatchDate.waitForExistence(timeout: 2) { patch.tap() }
        XCTAssertTrue(firstPatchDate.waitForExistence(timeout: 3))
        backToSettings(from: "Birth Control", in: app)

        openSetting("Reminders", in: app, expects: "Reminders")
        XCTAssertTrue(app.staticTexts["How Caelyn's reminders work"].exists)
        XCTAssertTrue(app.switches["Period start"].exists)
        backToSettings(from: "Reminders", in: app)

        openSetting("How Caelyn works", in: app, expects: "How Caelyn Works")
        XCTAssertTrue(app.staticTexts["Small logs become a clearer picture"].exists)
        let replayTips = app.buttons["Show first-use tips again"]
        reveal(replayTips, in: app)
        replayTips.tap()
        XCTAssertTrue(app.alerts["Tips are ready"].waitForExistence(timeout: 3))
        app.alerts["Tips are ready"].buttons["OK"].tap()
        capture("Simulator-Settings-Guide", app: app)
    }

    /// Specialist modes are highly stateful, so check their real transitions and
    /// the Home cards they produce rather than merely asserting the toggles exist.
    func testSpecialistModeTransitionsReachHome() throws {
        let app = launchSeeded()
        tapTab("Settings", in: app)
        openSetting("Cycle & period length", in: app, expects: "Cycle settings")

        for label in ["Irregular cycle mode", "Gentle guidance", "Perimenopause mode", "Endometriosis", "PCOS", "Trying to Conceive"] {
            let toggle = app.switches[label]
            reveal(toggle, in: app)
            if toggle.value as? String != "1" { toggle.tap() }
            let enabled = app.switches.matching(
                NSPredicate(format: "label == %@ AND value == %@", label, "1")
            ).firstMatch
            XCTAssertTrue(enabled.waitForExistence(timeout: 3), "\(label) should turn on")
            XCTAssertTrue(app.navigationBars["Cycle settings"].exists)
        }

        let pregnancy = app.switches["Pregnancy mode"]
        reveal(pregnancy, in: app)
        pregnancy.tap()
        let pregnancyEnabled = app.switches.matching(
            NSPredicate(format: "label == %@ AND value == %@", "Pregnancy mode", "1")
        ).firstMatch
        XCTAssertTrue(pregnancyEnabled.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Due date"].exists)
        app.navigationBars["Cycle settings"].buttons["Done"].tap()

        tapTab("Home", in: app)
        let pregnancyCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Pregnancy:")
        ).firstMatch
        reveal(pregnancyCard, in: app)
        XCTAssertTrue(pregnancyCard.exists, "Pregnancy mode should add its Home card")

        tapTab("Settings", in: app)
        openSetting("Cycle & period length", in: app, expects: "Cycle settings")
        let pregnancyAgain = app.switches["Pregnancy mode"]
        reveal(pregnancyAgain, in: app)
        pregnancyAgain.tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3) || app.buttons["I gave birth 💛"].waitForExistence(timeout: 3))
        app.buttons["I gave birth 💛"].tap()
        app.navigationBars["Cycle settings"].buttons["Done"].tap()

        tapTab("Home", in: app)
        let postpartumCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Postpartum:")
        ).firstMatch
        reveal(postpartumCard, in: app)
        XCTAssertTrue(postpartumCard.exists, "Birth transition should replace Pregnancy with Postpartum")
        Thread.sleep(forTimeInterval: 2.0) // Let the tab/navigation transition settle before visual QA.
        capture("Simulator-Postpartum-Transition", app: app)
    }

    /// Runs the highest-risk privacy feature end-to-end in the disposable seeded
    /// store: create both PINs, lock the app, then use the duress PIN and verify
    /// the app becomes a genuine first launch.
    func testPINLockAndDuressWipeEndToEnd() throws {
        let app = launchSeeded(extraArguments: ["--ui-test-disable-device-auth"])
        tapTab("Settings", in: app)
        openSetting("App PIN", in: app, expects: "App PIN")

        if app.buttons["Remove PIN"].exists {
            app.buttons["Remove PIN"].tap()
        }
        app.buttons["Set a PIN"].tap()
        XCTAssertTrue(app.staticTexts["Set a PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        XCTAssertTrue(app.staticTexts["Confirm your PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        XCTAssertTrue(app.buttons["Change PIN"].waitForExistence(timeout: 6), "Primary PIN should be saved")

        // A duress PIN is typed into the lock screen, so it cannot be armed while
        // App Lock is off — there would be nowhere to enter it, and she would be
        // holding a wipe that silently never fires. So the lock goes on first.
        XCTAssertFalse(app.buttons["Set a duress PIN"].isEnabled,
                       "Arming a duress PIN with App Lock off gives her a wipe that can never be triggered.")
        backToSettings(from: "App PIN", in: app)

        let lockToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "lock")).firstMatch
        reveal(lockToggle, in: app)
        lockToggle.tap()
        if lockToggle.value as? String != "1" {
            lockToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(lockToggle.value as? String, "1")
        if openPINEntry(in: app) {
            enterPIN("1234", in: app)
            XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        }

        openSetting("App PIN", in: app, expects: "App PIN")
        let setDuress = app.buttons["Set a duress PIN"]
        XCTAssertTrue(setDuress.waitForExistence(timeout: 3))
        XCTAssertTrue(setDuress.isEnabled, "With App Lock on, the duress PIN is reachable and may be armed.")
        setDuress.tap()
        XCTAssertTrue(app.staticTexts["Set a duress PIN"].waitForExistence(timeout: 3))
        enterPIN("4321", in: app)
        XCTAssertTrue(app.staticTexts["Confirm your PIN"].waitForExistence(timeout: 3))
        enterPIN("4321", in: app)
        XCTAssertTrue(app.buttons["Remove duress PIN"].waitForExistence(timeout: 6))
        backToSettings(from: "App PIN", in: app)

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.0)
        app.activate()
        XCTAssertTrue(openPINEntry(in: app), "Backgrounding should re-lock Caelyn")
        enterPIN("4321", in: app)
        XCTAssertTrue(app.staticTexts["Meet Caelyn"].waitForExistence(timeout: 12), "Duress PIN should wipe every record and return to first launch")
        XCTAssertFalse(app.buttons["Home"].exists)
        capture("Simulator-Duress-Wipe-First-Launch", app: app)
    }

    /// Verifies the remaining destructive/privacy Settings controls through the
    /// real UI, including both confirmations required for a normal data wipe.
    func testPrivacyControlsAndDeleteAllDataJourney() throws {
        let app = launchSeeded()
        tapTab("Settings", in: app)

        let hidePreview = app.switches["Hide app preview"]
        reveal(hidePreview, in: app)
        if hidePreview.value as? String != "1" { hidePreview.tap() }
        XCTAssertEqual(hidePreview.value as? String, "1")

        let privateNotifications = app.switches["Private notifications"]
        reveal(privateNotifications, in: app)
        if privateNotifications.value as? String != "0" { privateNotifications.tap() }
        XCTAssertEqual(privateNotifications.value as? String, "0")
        privateNotifications.tap()
        XCTAssertEqual(privateNotifications.value as? String, "1")

        let autoErase = app.switches["Auto-erase if inactive"]
        reveal(autoErase, in: app)
        if autoErase.value as? String != "1" {
            autoErase.tap()
            // Arming this destroys everything on a timer, with no prompt at the
            // moment it fires, so it confirms first.
            let armAutoErase = app.buttons["Turn on auto-erase"]
            XCTAssertTrue(armAutoErase.waitForExistence(timeout: 5),
                          "Auto-erase deletes everything unprompted; it must confirm before arming.")
            armAutoErase.tap()
        }
        // Waited for rather than read instantly: the confirmation dismisses with
        // an animation, and the switch redraws behind it.
        XCTAssertTrue(waitForSwitch(autoErase, toBe: "1"),
                      "Arming auto-erase did not turn the switch on.")

        let paranoidMode = settingButton("Paranoid Mode", in: app)
        reveal(paranoidMode, in: app)
        paranoidMode.tap()
        // Match the dialog, then the button inside it. SwiftUI's confirmationDialog
        // does not reliably expose its title as the element identifier, which is why
        // the working query elsewhere in this file uses firstMatch.
        let lockDown = app.buttons["Lock everything down"]
        XCTAssertTrue(lockDown.waitForExistence(timeout: 5),
                      "Paranoid Mode should confirm before changing several settings at once.")
        lockDown.tap()
        XCTAssertEqual(hidePreview.value as? String, "1")
        XCTAssertEqual(privateNotifications.value as? String, "1")

        let deleteAll = settingButton("Delete all data", in: app)
        reveal(deleteAll, in: app)
        deleteAll.tap()
        // As above, confirmationDialog is not exposed as a `sheets` element here,
        // so assert on the buttons it presents — which is what matters anyway.
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5),
                      "Deleting everything should ask first.")
        continueButton.tap()
        // Assert on the button unique to the second dialog: it is the thing that
        // proves a second confirmation stands between her and losing everything.
        let deleteEverything = app.buttons["Delete everything"]
        XCTAssertTrue(deleteEverything.waitForExistence(timeout: 4),
                      "A second confirmation must stand between her and deletion.")
        deleteEverything.tap()
        XCTAssertTrue(app.staticTexts["Meet Caelyn"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.buttons["Home"].exists)
        capture("Simulator-Delete-All-Data-First-Launch", app: app)
    }

    /// The appearance picker promises an app-wide theme, so visually capture all
    /// primary content tabs after selecting Dark rather than checking Settings only.
    func testDarkAppearanceAcrossPrimaryTabs() throws {
        let app = launchSeeded()
        tapTab("Settings", in: app)
        let appearance = settingButton("Appearance", in: app)
        reveal(appearance, in: app)
        appearance.tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 3))
        app.buttons["Dark"].tap()

        for tab in ["Home", "Calendar", "Log", "Insights"] {
            tapTab(tab, in: app)
            Thread.sleep(forTimeInterval: 1.0)
            capture("Simulator-Dark-\(tab)", app: app)
        }
    }

    private func tapButton(
        _ label: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Missing button: \(label)", file: file, line: line)
        for _ in 0..<20 where !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable, "Button is not reachable: \(label)", file: file, line: line)
        button.tap()
    }

    /// A sheet that was open when Caelyn locked must not stay on screen above the
    /// lock.
    ///
    /// The lock screen is a sibling in a `ZStack` and hides the content behind it
    /// by setting its opacity to zero. A presented sheet is not behind it: UIKit
    /// presents it in its own layer above the whole SwiftUI hierarchy, so the
    /// opacity never reaches it. Anyone who picks up her phone while a sheet was
    /// open — the day detail with her flow and symptoms on it, the export sheet,
    /// her history import — reads it over the top of a lock screen that believes
    /// it is covering everything. Which is the one thing App Lock exists to stop.
    func testASheetDoesNotStayVisibleAboveTheLockScreen() throws {
        let app = launchSeeded(extraArguments: ["--ui-test-disable-device-auth"])
        tapTab("Settings", in: app)
        openSetting("App PIN", in: app, expects: "App PIN")
        if app.buttons["Remove PIN"].exists { app.buttons["Remove PIN"].tap() }
        app.buttons["Set a PIN"].tap()
        XCTAssertTrue(app.staticTexts["Set a PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        XCTAssertTrue(app.staticTexts["Confirm your PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        XCTAssertTrue(app.buttons["Change PIN"].waitForExistence(timeout: 6))
        backToSettings(from: "App PIN", in: app)

        let lockToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "lock")).firstMatch
        reveal(lockToggle, in: app)
        if lockToggle.value as? String != "1" {
            lockToggle.tap()
            if lockToggle.value as? String != "1" {
                lockToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
        }
        XCTAssertEqual(lockToggle.value as? String, "1")
        if openPINEntry(in: app) {
            enterPIN("1234", in: app)
            XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        }

        // Open a sheet that is showing her data, and leave it open.
        let appearance = settingButton("Appearance", in: app)
        reveal(appearance, in: app)
        appearance.tap()
        XCTAssertTrue(app.staticTexts["Pick how Caelyn looks."].waitForExistence(timeout: 5),
                      "the appearance sheet should be open")

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.0)
        app.activate()

        XCTAssertTrue(app.staticTexts["Caelyn is locked"].waitForExistence(timeout: 6)
                      || app.staticTexts["Enter PIN"].waitForExistence(timeout: 2),
                      "Caelyn should be locked after backgrounding")
        capture("Lock-With-Sheet-Open", app: app)

        // The sheet's own content must be unreachable. If it is still hittable, the
        // sheet is drawn above the lock and someone holding her phone can read and
        // use it.
        XCTAssertFalse(app.staticTexts["Pick how Caelyn looks."].isHittable,
            "a sheet that was open when Caelyn locked is still on screen above the lock screen")
        XCTAssertFalse(app.buttons["Done"].isHittable,
            "the sheet above the lock screen is still interactive")
    }

    /// Wait for a switch to settle on a value. `element.value` is a one-shot
    /// snapshot, so reading it straight after a tap that dismisses a dialog races
    /// the redraw behind the animation.
    private func waitForSwitch(_ element: XCUIElement, toBe value: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func launchSeeded(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode",
            "-caelyn.firstFlowCelebrated", "NO",
            "-caelyn.firstWeekCelebrated", "NO"
        ] + extraArguments
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        return app
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        // The keyboard covers the tab bar on a phone, so every tab button reports
        // isHittable == false while it is up and the tap lands on a key instead.
        // That is what made this suite's journey test fail for reasons that had
        // nothing to do with what it was testing. Put the keyboard away first —
        // which is also what a person does, now there is a Done button to do it
        // with.
        dismissKeyboardIfPresent(in: app)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Missing tab: \(label)")
        button.tap()
    }

    /// Dismiss the keyboard via the app's own Done button, falling back to the
    /// interactive drag for any field that predates it.
    func dismissKeyboardIfPresent(in app: XCUIApplication) {
        guard app.keyboards.element.exists else { return }
        let done = app.buttons["keyboardDone"]
        if done.exists && done.isHittable {
            done.tap()
        } else {
            app.swipeDown()
        }
        // Give the keyboard time to retract before anything under it is tapped.
        _ = app.keyboards.element.waitForNonExistence(timeout: 3)
    }

    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 18,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // Anything under the keyboard is unreachable no matter how far we scroll,
        // and `isHittable` does not account for the keyboard overlay — so the tap
        // lands on a key and the next action fails somewhere unrelated. Put the
        // keyboard away first, which is what a person has to do too.
        dismissKeyboardIfPresent(in: app)
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Element is not reachable: \(element)", file: file, line: line)
    }

    private func settingButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", title)).firstMatch
    }

    private func revealFromBottom(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 18,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable, "Element is not reachable: \(element)", file: file, line: line)
    }

    private func openSetting(_ title: String, in app: XCUIApplication, expects navigationTitle: String) {
        let row = settingButton(title, in: app)
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.navigationBars[navigationTitle].waitForExistence(timeout: 4), "\(title) should open \(navigationTitle)")
    }

    private func backToSettings(from navigationTitle: String, in app: XCUIApplication) {
        let navigationBar = app.navigationBars[navigationTitle]
        let back = navigationBar.buttons["Settings"]
        if back.waitForExistence(timeout: 2) {
            back.tap()
        } else {
            navigationBar.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    private func enterPIN(_ pin: String, in app: XCUIApplication) {
        for digit in pin.map(String.init) {
            let button = app.buttons[digit]
            XCTAssertTrue(button.waitForExistence(timeout: 2), "PIN digit \(digit) should be available")
            button.tap()
            Thread.sleep(forTimeInterval: 0.15)
        }
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func openPINEntry(in app: XCUIApplication) -> Bool {
        if app.staticTexts["Enter PIN"].waitForExistence(timeout: 3) { return true }
        guard app.staticTexts["Caelyn is locked"].waitForExistence(timeout: 3) else { return false }
        let usePIN = app.buttons["Use PIN instead"]
        guard usePIN.waitForExistence(timeout: 2) else { return false }
        usePIN.tap()
        return app.staticTexts["Enter PIN"].waitForExistence(timeout: 3)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension CaelynUITests {

    /// The system authentication sheet must appear *above* the lock window.
    ///
    /// **Why this is the riskiest thing in Phase 0.** The lock moved out of the
    /// view hierarchy and into a `UIWindow` at `.alert + 1` so that it covers
    /// presented sheets. That is the whole point — but it raises the opposite
    /// question immediately: if an app window now sits above everything, does it
    /// also sit above the Face ID / passcode sheet that `LAContext` puts up?
    ///
    /// If it does, a woman with App Lock on cannot authenticate: the sheet is
    /// behind an opaque lock screen, her taps land on the wrong layer, and she is
    /// shut out of her own history with no route back short of deleting the app.
    /// The reasoning says this cannot happen — `LAContext` renders out of process
    /// and SpringBoard composites system UI above every app window regardless of
    /// level — but the cost of the reasoning being wrong is total, so it is
    /// checked on real hardware instead.
    ///
    /// Device-only: the simulator has no device-owner authentication to present.
    func testTheSystemAuthSheetAppearsAboveTheLockWindow() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("device-owner authentication cannot be exercised in the simulator")
        #else
        let app = launchSeeded()          // no --ui-test-disable-device-auth: real auth
        addTeardownBlock { Self.disableLockAndPIN(in: app) }

        // A Caelyn PIN first, so there is always a way back in if the system
        // sheet refuses — this test must not be able to strand the device.
        tapTab("Settings", in: app)
        openSetting("App PIN", in: app, expects: "App PIN")
        if app.buttons["Remove PIN"].exists { app.buttons["Remove PIN"].tap() }
        app.buttons["Set a PIN"].tap()
        XCTAssertTrue(app.staticTexts["Set a PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        XCTAssertTrue(app.staticTexts["Confirm your PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        XCTAssertTrue(app.buttons["Change PIN"].waitForExistence(timeout: 6))
        backToSettings(from: "App PIN", in: app)

        let lockToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "lock")).firstMatch
        reveal(lockToggle, in: app)
        if lockToggle.value as? String != "1" {
            // Exactly one tap, on the knob — a centre tap lands on the label and
            // does nothing. A retry tap would land behind the system prompt below
            // and could switch the lock straight back off.
            lockToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        // The first Face ID use asks iOS's one-time "Allow Caelyn to use Face
        // ID?" question. While it is up, the app cannot be snapshotted at all —
        // every query against it hangs for 30 s and the run dies — so it has to
        // be answered through SpringBoard before the app is touched again.
        Self.allowFaceIDIfAsked()
        XCTAssertEqual(lockToggle.value as? String, "1")

        // Background and come back: the gate locks and, because device auth is
        // available, immediately asks for it.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.0)
        app.activate()

        // Coming back must prompt by itself. With no enrolled face in view the
        // scan fails and iOS raises its "Face Not Recognized" sheet — the
        // system UI whose layering this test exists to check.
        //
        // Run it with the phone face-down or nobody in front of it: if Face ID
        // recognises someone, the app unlocks before there is a sheet to test.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let cancel = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Cancel'")).firstMatch
        // "Unlocked" means the lock screen has gone — not that some app control
        // exists, because the app's tree is still there underneath the lock.
        let lockScreen = app.staticTexts["Caelyn is locked"]
        XCTAssertTrue(lockScreen.waitForExistence(timeout: 5), "returning did not lock Caelyn")
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, !cancel.exists, lockScreen.exists {
            Thread.sleep(forTimeInterval: 0.5)
        }
        capture("JOY-SystemAuth-Over-LockWindow", app: app)

        if !lockScreen.exists, !cancel.exists {
            // The prompt came up over the lock and a face it knows unlocked the
            // app — the sheet was reachable. The cancel path was not exercised.
            XCTFail("Face ID recognised a face and unlocked before the cancel path could run; re-run with the phone face-down")
            return
        }
        XCTAssertTrue(cancel.exists,
            "returning to a locked Caelyn did not raise the system authentication sheet")
        XCTAssertTrue(cancel.isHittable,
            "the system authentication sheet is on screen but not reachable — the lock window at .alert + 1 is covering it, and App Lock users cannot get into their own history")

        // The passcode fallback: `.deviceOwnerAuthentication` must offer her
        // device passcode once Face ID has failed, and that pad must also come
        // up above the lock window. Her passcode is never typed here.
        let tryAgain = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Try Face ID Again'")).firstMatch
        let enterPasscode = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Enter Passcode'")).firstMatch
        if !enterPasscode.exists, tryAgain.exists {
            tryAgain.tap()
            let deadline = Date().addingTimeInterval(15)
            while Date() < deadline, !enterPasscode.exists, lockScreen.exists {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTAssertTrue(enterPasscode.exists,
            "after Face ID failed, iOS offered no passcode fallback over the lock")
        capture("JOY-Passcode-Offered", app: app)
        enterPasscode.tap()
        let passcodePad = springboard.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'Passcode'")).firstMatch
        XCTAssertTrue(passcodePad.waitForExistence(timeout: 5),
            "the device passcode pad did not appear")
        Thread.sleep(forTimeInterval: 1.0)
        capture("JOY-Passcode-Over-LockWindow", app: app)
        XCTAssertTrue(cancel.waitForExistence(timeout: 3) && cancel.isHittable,
            "the passcode pad is up but cannot be dismissed")
        cancel.tap()

        // Cancel has to stick. Dismissing the sheet returns the scene to active,
        // and the gate once read that as a fresh return and put the sheet
        // straight back up — leaving "Use PIN instead", and any duress PIN
        // behind it, reachable only between prompts.
        Thread.sleep(forTimeInterval: 4.0)
        capture("JOY-After-Cancel", app: app)
        XCTAssertFalse(cancel.exists,
            "cancelling the system sheet re-prompted at once — she can never get to her PIN")
        XCTAssertTrue(app.staticTexts["Caelyn is locked"].exists,
            "after Cancel she must be left on Caelyn's lock screen")

        // Whatever happened, she must be able to get back in.
        XCTAssertTrue(openPINEntry(in: app), "the lock screen offered no way back in")
        enterPIN("1234", in: app)
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8),
                      "Caelyn's own PIN did not unlock the app")
        #endif
    }

    /// The duress PIN must still wipe after the lockout has engaged, and the real
    /// wipe — reached the way she reaches it — must leave nothing on the device.
    ///
    /// Opt-in and device-only, because it plants residue in the real Keychain and
    /// containers. Read the device afterwards with
    /// `CaelynTests/WipeForensicsTests` (`CAELYN_WIPE_FORENSICS=survivors-must-be-empty`).
    func testDuressWipeAfterLockoutLeavesNothingOnDevice() throws {
        guard ProcessInfo.processInfo.environment["CAELYN_DEVICE_FORENSICS"] == "1" else {
            throw XCTSkip("plants residue in the real Keychain; opt in with CAELYN_DEVICE_FORENSICS=1")
        }
        let app = launchSeeded(extraArguments: ["--ui-test-disable-device-auth", "--ui-test-plant-residue"])

        tapTab("Settings", in: app)
        openSetting("App PIN", in: app, expects: "App PIN")
        if app.buttons["Remove PIN"].exists { app.buttons["Remove PIN"].tap() }
        app.buttons["Set a PIN"].tap()
        XCTAssertTrue(app.staticTexts["Set a PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        XCTAssertTrue(app.staticTexts["Confirm your PIN"].waitForExistence(timeout: 3))
        enterPIN("1234", in: app)
        // If App Lock was already on, a PIN is now a way in, so Caelyn locks.
        if openPINEntry(in: app) { enterPIN("1234", in: app) }
        XCTAssertTrue(app.buttons["Change PIN"].waitForExistence(timeout: 6))
        backToSettings(from: "App PIN", in: app)

        let lockToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "lock")).firstMatch
        reveal(lockToggle, in: app)
        if lockToggle.value as? String != "1" {
            lockToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(lockToggle.value as? String, "1")
        if openPINEntry(in: app) {
            enterPIN("1234", in: app)
            XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        }

        openSetting("App PIN", in: app, expects: "App PIN")
        app.buttons["Set a duress PIN"].tap()
        XCTAssertTrue(app.staticTexts["Set a duress PIN"].waitForExistence(timeout: 3))
        enterPIN("4321", in: app)
        XCTAssertTrue(app.staticTexts["Confirm your PIN"].waitForExistence(timeout: 3))
        enterPIN("4321", in: app)
        XCTAssertTrue(app.buttons["Remove duress PIN"].waitForExistence(timeout: 6))
        backToSettings(from: "App PIN", in: app)

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.0)
        app.activate()
        XCTAssertTrue(openPINEntry(in: app), "backgrounding should re-lock Caelyn")

        // Whoever is holding her phone burns through every attempt.
        for _ in 0..<5 { enterPIN("0000", in: app) }
        let lockedOut = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Too many attempts'")).firstMatch
        XCTAssertTrue(lockedOut.waitForExistence(timeout: 3), "five wrong PINs should engage the lockout")
        capture("JOY-Duress-After-Lockout", app: app)

        // The scenario the duress PIN exists for: it must still wipe.
        enterPIN("4321", in: app)
        XCTAssertTrue(app.staticTexts["Meet Caelyn"].waitForExistence(timeout: 15),
                      "the duress PIN was refused by the lockout — the one moment it is ever typed")
        XCTAssertFalse(app.buttons["Home"].exists)
        XCTAssertFalse(lockedOut.exists, "the app handed back still shows the lockout")
        capture("JOY-Duress-Wipe-First-Launch", app: app)

        // What the wipe left on this device, read inside the process that wiped —
        // once it has finished, and again later, so nothing may re-arm itself.
        let readout = app.staticTexts["UIA.WipeResidue.Survivors"]
        XCTAssertTrue(readout.waitForExistence(timeout: 5))
        let settled = NSPredicate(format: "label == 'none'")
        expectation(for: settled, evaluatedWith: readout)
        waitForExpectations(timeout: 15)
        Thread.sleep(forTimeInterval: 5)
        XCTAssertEqual(readout.label, "none", "residue reappeared after the wipe: \(readout.label)")
        capture("JOY-Duress-Wipe-Residue-None", app: app)
    }

    /// Control for the forensics: plant the residue and do nothing else, so the
    /// forensic reader can be shown to see every kind. Opt-in, device-only.
    func testPlantWipeResidueOnly() throws {
        guard ProcessInfo.processInfo.environment["CAELYN_DEVICE_FORENSICS"] == "control" else {
            throw XCTSkip("forensics control; opt in with CAELYN_DEVICE_FORENSICS=control")
        }
        let app = launchSeeded(extraArguments: ["--ui-test-plant-residue"])
        let readout = app.staticTexts["UIA.WipeResidue.Survivors"]
        XCTAssertTrue(readout.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5)
        for planted in ["temp export", "default.store.corrupt-", "CaelynImportLedger.json",
                        "Apple user ID", "widget snapshot", "auto-erase"] {
            XCTAssertTrue(readout.label.contains(planted),
                "control: planted \(planted) is not detected, so a clean reading would prove nothing — \(readout.label)")
        }
        capture("JOY-Residue-Control", app: app)
        // Leave the device as found: the plant put a fake Apple identity in the
        // real Keychain and armed auto-erase.
        app.terminate()
        let cleanup = XCUIApplication()
        cleanup.launchArguments = ["--screenshot-mode", "--ui-test-clear-residue"]
        cleanup.launch()
        XCTAssertTrue(cleanup.buttons["Home"].waitForExistence(timeout: 10))
        cleanup.terminate()
    }

    /// Answer iOS's one-time Face ID permission prompt, if it is showing.
    private static func allowFaceIDIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
    }

    /// Leave the device as we found it: no lock, no PIN.
    private static func disableLockAndPIN(in app: XCUIApplication) {
        guard app.state == .runningForeground else { return }
        let lockToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "lock")).firstMatch
        if lockToggle.exists, lockToggle.value as? String == "1" { lockToggle.tap() }
        let pinRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "App PIN")).firstMatch
        if pinRow.exists {
            pinRow.tap()
            if app.buttons["Remove PIN"].waitForExistence(timeout: 3) { app.buttons["Remove PIN"].tap() }
        }
    }
}
