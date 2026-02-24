import UIKit
import XCTest

final class GymTimerProUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSnapshots() throws {
        if isDarkModeSnapshot {
            let timerApp = launchApp(sets: 6, rest: 60)
            waitForElement(timerApp.descendants(matching: .any)["homeScreen"], timeout: 15)

            let startRestButton = timerApp.descendants(matching: .any)["startRestButton"]
            waitForElement(startRestButton, timeout: 15)
            startRestButton.tap()

            let restingView = timerApp.descendants(matching: .any)["restTimerView"]
            waitForElement(restingView, timeout: 15)
            snapshot("02_Timer")
            timerApp.terminate()

            let notificationApp = launchApp(sets: 5, rest: 75, currentSet: 5, showNotificationPreview: true)
            let preview = notificationApp.descendants(matching: .any)["notificationPreview"]
            waitForElement(preview, timeout: 15)
            snapshot("04_Notification")
            notificationApp.terminate()
        } else {
            let homeApp = launchApp(sets: 4, rest: 90)
            waitForElement(homeApp.descendants(matching: .any)["homeScreen"], timeout: 15)
            snapshot("01_Home")
            homeApp.terminate()

            let wheelApp = launchApp(sets: 8, rest: 120)
            waitForElement(wheelApp.descendants(matching: .any)["homeScreen"], timeout: 15)

            let totalSetsButton = wheelApp.descendants(matching: .any)["totalSetsValueButton"]
            waitForElement(totalSetsButton, timeout: 15)
            totalSetsButton.tap()

            let picker = wheelApp.descendants(matching: .any)["totalSetsPicker"]
            waitForElement(picker, timeout: 15)
            snapshot("03_Wheel")
            wheelApp.terminate()
        }
    }

    @MainActor
    func testRoutineListOpensEditor() throws {
        let app = launchApp(sets: 4, rest: 90, isPro: true)
        let routinesTab = app.tabBars.buttons.element(boundBy: 1)
        waitForElement(routinesTab, timeout: 10)
        routinesTab.tap()

        let routineCell = app.staticTexts["Resistencia"]
        waitForElement(routineCell, timeout: 15)
        routineCell.tap()

        let editorNavBar = app.navigationBars["Resistencia"]
        waitForElement(editorNavBar, timeout: 10)
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
    private func launchApp(
        sets: Int,
        rest: Int,
        currentSet: Int? = nil,
        showNotificationPreview: Bool = false,
        isPro: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["ui-testing-seed-routines"]
        if isPro {
            app.launchArguments += ["-purchase.cachedIsPro", "1"]
        }
        app.launchEnvironment["UITEST_TOTAL_SETS"] = "\(sets)"
        app.launchEnvironment["UITEST_REST_SECONDS"] = "\(rest)"
        if let currentSet {
            app.launchEnvironment["UITEST_CURRENT_SET"] = "\(currentSet)"
        }
        if showNotificationPreview {
            app.launchEnvironment["UITEST_SHOW_NOTIFICATION_PREVIEW"] = "1"
        }
        app.launch()
        return app
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
