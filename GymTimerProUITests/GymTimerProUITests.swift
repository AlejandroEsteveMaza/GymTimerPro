import UIKit
import XCTest

final class GymTimerProUITests: XCTestCase {

    private struct LaunchOptions {
        var sets: Int = 4
        var restSeconds: Int = 90
        var currentSet: Int? = nil
        var showNotificationPreview = false
        var isPro = false
        var seedRoutines = true
        var resetRoutines = false
        var resetProgress = false
        var seedProgressYearHeavy = false
        var forcePaywallEntry: String? = nil
        var forcePaywallInfoLevel: String? = nil
        var usageConsumed: Int? = nil
        var openRoutineEditor = false
        var progressPeriod: String? = nil
        var progressSelectDay = false
        var keepPaywallVisibleForPro = false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSnapshots() throws {
        if isDarkModeSnapshot {
            captureDarkModeSnapshots()
            return
        }

        captureTrainingSnapshots()
        captureRoutineSnapshots()
        captureProgressSnapshots()
        captureSettingsSnapshots()
        capturePaywallSnapshots()
    }

    @MainActor
    private func captureTrainingSnapshots() {
        let homeApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false
            )
        )
        waitForElement(homeApp.descendants(matching: .any)["homeScreen"], timeout: 15)
        snapshot("01_Home")
        homeApp.terminate()

        let restApp = launchApp(
            LaunchOptions(
                sets: 6,
                restSeconds: 60,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false
            )
        )
        waitForElement(restApp.descendants(matching: .any)["homeScreen"], timeout: 15)
        let startRestButton = restApp.descendants(matching: .any)["startRestButton"]
        waitForElement(startRestButton, timeout: 15)
        startRestButton.tap()
        waitForElement(restApp.descendants(matching: .any)["restTimerView"], timeout: 15)
        snapshot("02_Timer")
        restApp.terminate()

        let completedApp = launchApp(
            LaunchOptions(
                sets: 1,
                restSeconds: 30,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false
            )
        )
        waitForElement(completedApp.descendants(matching: .any)["homeScreen"], timeout: 15)
        let completeButton = completedApp.descendants(matching: .any)["startRestButton"]
        waitForElement(completeButton, timeout: 15)
        completeButton.tap()
        waitForElement(completedApp.staticTexts["WORKOUT COMPLETED!"], timeout: 10)
        snapshot("05_TrainingCompleted")
        completedApp.terminate()
    }

    @MainActor
    private func captureRoutineSnapshots() {
        let emptyApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: false,
                resetRoutines: true,
                resetProgress: false,
                seedProgressYearHeavy: false
            )
        )
        openTab(at: 1, in: emptyApp)
        waitForElement(emptyApp.staticTexts["No Routines"], timeout: 15)
        snapshot("10_RoutinesEmpty")
        emptyApp.terminate()

        let catalogApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: true,
                resetProgress: false,
                seedProgressYearHeavy: false,
                openRoutineEditor: false
            )
        )
        openTab(at: 1, in: catalogApp)
        let routineCell = catalogApp.staticTexts["Resistencia"]
        waitForElement(routineCell, timeout: 15)
        snapshot("11_RoutinesCatalog")
        catalogApp.terminate()

        let editorApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false,
                openRoutineEditor: true
            )
        )
        openTab(at: 1, in: editorApp)
        waitForElement(editorApp.buttons["Save"], timeout: 15)
        snapshot("12_RoutineEditor")
        editorApp.terminate()
    }

    @MainActor
    private func captureProgressSnapshots() {
        let monthApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: true,
                seedProgressYearHeavy: true,
                openRoutineEditor: false,
                progressPeriod: "month",
                progressSelectDay: false
            )
        )
        openTab(at: 2, in: monthApp)
        waitForElement(monthApp.navigationBars["Progress"], timeout: 15)
        snapshot("20_ProgressMonth")
        monthApp.terminate()

        let quarterApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: true,
                openRoutineEditor: false,
                progressPeriod: "quarter",
                progressSelectDay: false
            )
        )
        openTab(at: 2, in: quarterApp)
        waitForElement(quarterApp.navigationBars["Progress"], timeout: 15)
        snapshot("21_ProgressQuarter")
        quarterApp.terminate()

        let selectedDayApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: true,
                openRoutineEditor: false,
                progressPeriod: "month",
                progressSelectDay: true
            )
        )
        openTab(at: 2, in: selectedDayApp)
        waitForElement(selectedDayApp.navigationBars.element(boundBy: 1), timeout: 15)
        snapshot("22_ProgressSelectedDay")
        selectedDayApp.terminate()
    }

    @MainActor
    private func captureSettingsSnapshots() {
        let settingsApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false
            )
        )
        openTab(at: 3, in: settingsApp)
        waitForElement(settingsApp.navigationBars["Settings"], timeout: 15)
        snapshot("30_SettingsDefault")

        let weightUnitPicker = settingsApp.descendants(matching: .any)["settingsWeightUnitPicker"]
        waitForElement(weightUnitPicker, timeout: 10)
        weightUnitPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        sleep(1)
        snapshot("31_SettingsMenu")
        settingsApp.terminate()
    }

    @MainActor
    private func capturePaywallSnapshots() {
        capturePaywallSnapshot(
            name: "40_PaywallStandardPro",
            entryPoint: "proModule",
            infoLevel: "standard",
            expectedTitle: "Train with full potential"
        )

        capturePaywallSnapshot(
            name: "41_PaywallLightLimit",
            entryPoint: "dailyLimitDuringWorkout",
            infoLevel: "light",
            expectedTitle: "Keep training without cuts"
        )

        capturePaywallSnapshot(
            name: "42_PaywallDetailedPro",
            entryPoint: "proModule",
            infoLevel: "detailed",
            expectedTitle: "Unlock everything Pro offers"
        )
    }

    @MainActor
    private func capturePaywallSnapshot(
        name: String,
        entryPoint: String,
        infoLevel: String,
        expectedTitle: String
    ) {
        let paywallApp = launchApp(
            LaunchOptions(
                sets: 4,
                restSeconds: 90,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false,
                forcePaywallEntry: entryPoint,
                forcePaywallInfoLevel: infoLevel,
                openRoutineEditor: false,
                progressPeriod: nil,
                progressSelectDay: false,
                keepPaywallVisibleForPro: true
            )
        )
        waitForElement(paywallApp.staticTexts[expectedTitle], timeout: 15)
        snapshot(name)
        paywallApp.terminate()
    }

    @MainActor
    private func captureDarkModeSnapshots() {
        let timerApp = launchApp(
            LaunchOptions(
                sets: 6,
                restSeconds: 60,
                currentSet: 1,
                showNotificationPreview: false,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false
            )
        )
        waitForElement(timerApp.descendants(matching: .any)["homeScreen"], timeout: 15)
        let startRestButton = timerApp.descendants(matching: .any)["startRestButton"]
        waitForElement(startRestButton, timeout: 15)
        startRestButton.tap()
        waitForElement(timerApp.descendants(matching: .any)["restTimerView"], timeout: 15)
        snapshot("02_Timer")
        timerApp.terminate()

        let notificationApp = launchApp(
            LaunchOptions(
                sets: 5,
                restSeconds: 75,
                currentSet: 5,
                showNotificationPreview: true,
                isPro: true,
                seedRoutines: true,
                resetRoutines: false,
                resetProgress: false,
                seedProgressYearHeavy: false
            )
        )
        waitForElement(notificationApp.descendants(matching: .any)["notificationPreview"], timeout: 15)
        snapshot("04_Notification")
        notificationApp.terminate()
    }

    private var isDarkModeSnapshot: Bool {
        if let value = ProcessInfo.processInfo.environment["SNAPSHOT_DARK_MODE"]?.lowercased() {
            return value == "true" || value == "1" || value == "yes"
        }
        if #available(iOS 13.0, *) {
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
        return false
    }

    @MainActor
    private func launchApp(_ options: LaunchOptions) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["ui-testing"]
        app.launchArguments += ["-purchase.cachedIsPro", options.isPro ? "1" : "0"]

        if options.seedRoutines {
            app.launchArguments += ["ui-testing-seed-routines"]
        }
        if options.resetRoutines {
            app.launchArguments += ["ui-testing-reset-routines"]
        }
        if options.resetProgress {
            app.launchArguments += ["seed-progress-reset"]
        }
        if options.seedProgressYearHeavy {
            app.launchArguments += ["seed-progress-year-heavy"]
        }

        app.launchEnvironment["UITEST_RESET_WORKOUT_STATE"] = "1"
        app.launchEnvironment["UITEST_TOTAL_SETS"] = "\(options.sets)"
        app.launchEnvironment["UITEST_REST_SECONDS"] = "\(options.restSeconds)"
        if let currentSet = options.currentSet {
            app.launchEnvironment["UITEST_CURRENT_SET"] = "\(currentSet)"
        }
        if options.showNotificationPreview {
            app.launchEnvironment["UITEST_SHOW_NOTIFICATION_PREVIEW"] = "1"
        }
        if let usageConsumed = options.usageConsumed {
            app.launchEnvironment["UITEST_USAGE_CONSUMED"] = "\(usageConsumed)"
        }
        if options.openRoutineEditor {
            app.launchEnvironment["UITEST_OPEN_ROUTINE_EDITOR"] = "1"
        }
        if let progressPeriod = options.progressPeriod {
            app.launchEnvironment["UITEST_PROGRESS_PERIOD"] = progressPeriod
        }
        if options.progressSelectDay {
            app.launchEnvironment["UITEST_PROGRESS_SELECT_DAY"] = "1"
        }
        if options.keepPaywallVisibleForPro {
            app.launchEnvironment["UITEST_KEEP_PAYWALL_VISIBLE_FOR_PRO"] = "1"
        }
        if let entryPoint = options.forcePaywallEntry, let infoLevel = options.forcePaywallInfoLevel {
            app.launchEnvironment["UITEST_PAYWALL_ENTRY"] = entryPoint
            app.launchEnvironment["UITEST_PAYWALL_INFO_LEVEL"] = infoLevel
        }

        app.launch()
        return app
    }

    private func openTab(at index: Int, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons.element(boundBy: index)
        waitForElement(tabButton, timeout: 10)
        tabButton.tap()
    }

    private func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("Element not found in time: \(element)", file: file, line: line)
        }
    }
}
