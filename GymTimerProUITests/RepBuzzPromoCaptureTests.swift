// Opt-in isolated capture target only. Production builds never compile this harness.
#if REPBUZZ_CAPTURE
import XCTest
import UIKit
import SwiftData
import StoreKit
import StoreKitTest

final class RepBuzzPromoCaptureTests: XCTestCase {
    private var locale = ""
    private var sample: [String: Any] = [:]
    private var chrome: [String: String] = [:]
    private var entitlement: SKTestSession!
    private var fixtureContainer = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        locale = try XCTUnwrap(ProcessInfo.processInfo.environment["PROMO_LOCALE"])
        let resource = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "promo-runtime", withExtension: "json"))
        let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: resource)) as? [String: Any])
        let locales = try XCTUnwrap(fixture["locales"] as? [String: [String: Any]])
        sample = try XCTUnwrap(locales[locale])
        chrome = try XCTUnwrap(sample["chrome"] as? [String: String])
    }

    @MainActor
    private func launch(sets: Int = 4, current: Int = 1, rest: Int = 90, reset: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // Native attachments need no shared Fastlane cache or duplicate locale args.
        app.launchArguments = [
            "-AppleLanguages", "(\(locale))", "-AppleLocale", sample["apple_locale"] as! String,
            "-AppleInterfaceStyle", "Light", "ui-testing", "-purchase.cachedIsPro", "0",
            "-weight.unit_preference", "1", "-timer.display_format", "0"
        ]
        if reset {
            app.launchArguments += ["ui-testing-reset-routines", "seed-progress-reset"]
        }
        app.launchEnvironment["UITEST_RESET_WORKOUT_STATE"] = "1"
        app.launchEnvironment["UITEST_TOTAL_SETS"] = "\(sets)"
        app.launchEnvironment["UITEST_CURRENT_SET"] = "\(current)"
        app.launchEnvironment["UITEST_REST_SECONDS"] = "\(rest)"
        app.launchEnvironment["UITEST_PROGRESS_PERIOD"] = "month"
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["homeScreen"].waitForExistence(timeout: 20))
        return app
    }

    /// Seed simulator user records with unchanged production models and creators.
    /// The runner copies these model/store source files into the scratch test target.
    @MainActor
    private func seedUserRecords() throws {
        // Xcode can reinstall the app after simctl install. Resolve its CURRENT
        // container only now, after launch/reset/termination, from bundle metadata.
        let root = URL(fileURLWithPath: try XCTUnwrap(
            ProcessInfo.processInfo.environment["PROMO_APP_CONTAINERS_ROOT"]))
        let directories = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let matches = directories.filter { directory in
            let metadata = directory.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let data = try? Data(contentsOf: metadata),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let values = plist as? [String: Any] else { return false }
            return values["MCMMetadataIdentifier"] as? String == "alejandroestevemaza.GymTimerPro"
        }
        guard matches.count == 1 else {
            throw NSError(domain: "PromoCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Expected exactly one CURRENT target app container; found \(matches.count)"
            ])
        }
        let store = matches[0].appendingPathComponent("Library/Application Support/GymTimerPro.store")
        guard FileManager.default.fileExists(atPath: store.path) else {
            throw NSError(domain: "PromoCapture", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Current target store missing after launch; refusing to create an ephemeral fixture store"
            ])
        }
        fixtureContainer = matches[0].lastPathComponent
        let schema = Schema([Routine.self, RoutineClassification.self, WorkoutCompletion.self])
        let config = ModelConfiguration("GymTimerPro", schema: schema,
                                        url: store, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Routine>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutCompletion>()), 0)
        let names = sample["routines"] as! [String]
        let categoryNames = sample["classifications"] as! [String]
        let categories = categoryNames.map { RoutineClassification(name: $0) }
        categories.forEach { context.insert($0) }
        let routinesStore = RoutinesStore()
        routinesStore.configure(context: context)
        // Same ordered parameters as production seedSampleRoutines; localized names only.
        let parameters: [(Int, Int, Int, Double?, Int?)] = [
            (5, 5, 120, 60, 0), (4, 10, 90, 22.5, 1), (6, 12, 60, nil, nil),
            (5, 5, 150, 80, 0), (5, 6, 120, 70, 0), (4, 8, 90, 35, nil),
            (4, 10, 90, 25, 1), (4, 10, 90, 25, 1), (3, 15, 60, nil, 3),
            (10, 20, 30, nil, 2), (8, 15, 45, nil, 2), (3, 8, 120, 20, 0),
            (4, 12, 30, nil, 3), (4, 12, 75, 15, 1)
        ]
        for (index, p) in parameters.enumerated() {
            routinesStore.create(from: RoutineDraft(name: names[index], totalSets: p.0,
                reps: p.1, restSeconds: p.2, weightKg: p.3,
                classifications: p.4.map { [categories[$0]] } ?? []))
        }
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertEqual(calendar.component(.year, from: Date()), 2026)
        XCTAssertEqual(calendar.component(.month, from: Date()), 11)
        for (index, day) in [2, 4, 6, 9, 11, 13].enumerated() {
            let date = try XCTUnwrap(calendar.date(from: DateComponents(
                year: 2026, month: 11, day: day, hour: 18, minute: 30)))
            XCTAssertLessThan(date, Date())
            let leg = index == 2 || index == 5
            context.insert(WorkoutCompletion(completedAt: date, routineID: nil,
                routineNameSnapshot: names[leg ? 3 : 1], classificationID: nil,
                classificationNameSnapshot: categoryNames[leg ? 0 : 1],
                durationSeconds: (leg ? 45 : 40) * 60, notes: "repbuzz-promo-local-fixture"))
        }
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Routine>()), 14)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutCompletion>()), 6)
    }

    @MainActor
    private func verifyPremium(_ app: XCUIApplication) {
        XCTAssertTrue(entitlement.allTransactions().contains {
            $0.productIdentifier == "premium_yearly" && $0.state == .purchased
        })
        XCTAssertTrue(app.staticTexts[chrome["pro.status.pro"]!].waitForExistence(timeout: 20),
                      "Uncached local entitlement must produce the app's actual Pro badge")
    }

    @MainActor
    private func closeTip(_ app: XCUIApplication, required: Bool) {
        let tip = app.staticTexts[chrome["tip.keep_app_open"]!]
        let appeared = tip.waitForExistence(timeout: required ? 5 : 0.2)
        if required { XCTAssertTrue(appeared, "Rest action must expose the notice before dismissing it") }
        if !appeared {
            XCTAssertFalse(tip.exists)
            return
        }
        // Inspect the actual tree before using geometry: this button has no stable identifier.
        print("TIP_ACCESSIBILITY_TREE\n\(app.debugDescription)")
        let frame = tip.frame
        let close = app.buttons.allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.midY >= frame.minY - 15
                && $0.frame.midY <= frame.maxY + 15 && $0.frame.minX > frame.maxX
        }
        if let close { close.tap() }
        else {
            tip.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: 20, dy: 0)).tap()
        }
        XCTAssertTrue(tip.waitForNonExistence(timeout: 3),
                      "The open-app alert must observably disappear before capture")
    }

    @MainActor
    private func tab(_ index: Int, _ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: index).tap()
    }

    @MainActor
    private func capture(_ screen: String, _ app: XCUIApplication, assertions: [String],
                         screenshot: XCUIScreenshot? = nil) throws {
        let bannerAbsent = !app.staticTexts[chrome["tip.keep_app_open"]!].exists
        XCTAssertTrue(bannerAbsent, "Never accept proof while the keep-open banner remains")
        let image = screenshot ?? app.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = screen + "__native"
        attachment.lifetime = .keepAlways
        add(attachment)
        let proof: [String: Any] = [
            "locale": locale, "screen_id": screen, "premium": true,
            "captured_at_utc": ISO8601DateFormatter().string(from: Date()),
            "assertions": assertions,
            "banner_absent": bannerAbsent,
            "fixture_container_identifier": fixtureContainer,
            "entitlement": "Local SKTestSession premium_yearly active; cachedIsPro=false on every launch; actual app Pro badge asserted before navigating",
            "fixture": "14 localized routines; six sessions Nov 2,4,6,9,11,13 2026; hypertrophy 4 / leg strength 2",
            "localized_chrome": chrome["workout.completed"]!,
            "apple_locale": sample["apple_locale"]!
        ]
        let data = try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys])
        let evidence = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        evidence.name = screen + "__proof"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    @MainActor
    func testCapturePromos() async throws {
        entitlement = try SKTestSession(configurationFileNamed: "GymTimerPro")
        entitlement.disableDialogs = true
        entitlement.resetToDefaultState()
        entitlement.clearTransactions()
        let purchase = try await entitlement.buyProduct(identifier: "premium_yearly")
        XCTAssertNil(purchase.revocationDate)
        XCTAssertGreaterThan(purchase.expirationDate ?? .distantPast, Date())

        let reset = launch(reset: true)
        verifyPremium(reset)
        // RoutinesStore.configure runs lazily when its tab first appears.
        tab(1, reset)
        XCTAssertTrue(reset.staticTexts[chrome["routines.empty.title"]!].waitForExistence(timeout: 10))
        reset.terminate()
        try autoreleasepool { try seedUserRecords() }

        let timer = launch(sets: 6, current: 1, rest: 60)
        verifyPremium(timer)
        // ConfigRow intentionally hides its visual Text from accessibility;
        // the wheel exposes this localized label as a standalone control.
        XCTAssertTrue(timer.descendants(matching: .any)[chrome["config.total_sets.title"]!].firstMatch.exists)
        timer.descendants(matching: .any)["startRestButton"].tap()
        XCTAssertTrue(timer.descendants(matching: .any)["restTimerView"].waitForExistence(timeout: 10))
        closeTip(timer, required: true)
        try capture("02_Timer", timer, assertions: [
            "homeScreen/startRestButton opened restTimerView; six total sets and 60-second rest",
            "Actual Pro badge and selected locale verified; keep-open alert closed"
        ])
        timer.terminate()

        let catalog = launch()
        verifyPremium(catalog)
        tab(1, catalog)
        XCTAssertTrue(catalog.navigationBars[chrome["routines.title"]!].waitForExistence(timeout: 10))
        let names = sample["routines"] as! [String]
        XCTAssertTrue(catalog.staticTexts[names[1]].firstMatch.exists)
        try capture("11_RoutinesCatalog", catalog, assertions: [
            "Localized navigation title: \(chrome["routines.title"]!)",
            "Localized sample routines rendered from simulator-only user records"
        ])
        catalog.terminate()

        let progress = launch()
        verifyPremium(progress)
        tab(2, progress)
        XCTAssertTrue(progress.navigationBars[chrome["progress.title"]!].waitForExistence(timeout: 10))
        XCTAssertTrue(progress.descendants(matching: .any)["progressPeriodPicker"].exists)
        try capture("20_ProgressMonth", progress, assertions: [
            "Localized progress title: \(chrome["progress.title"]!); month selected by existing UITEST_PROGRESS_PERIOD",
            "Six past November 2026 sessions; four hypertrophy and two leg-strength sessions"
        ])
        progress.terminate()

        let editor = launch()
        verifyPremium(editor)
        tab(1, editor)
        let fullBody = editor.staticTexts[names[5]].firstMatch
        for _ in 0..<10 where !fullBody.isHittable { editor.swipeUp() }
        XCTAssertTrue(fullBody.isHittable)
        fullBody.tap()
        XCTAssertTrue(editor.navigationBars[chrome["routines.edit.title"]!].waitForExistence(timeout: 10))
        XCTAssertEqual(editor.textFields[chrome["routines.field.name"]!].value as? String, names[5])
        XCTAssertEqual(editor.keyboards.count, 0)
        try capture("12_RoutineEditor", editor, assertions: [
            "Existing localized Full Body opened: \(names[5]); 4 sets, 8 reps, 90 seconds, 35 kg",
            "Localized editor title \(chrome["routines.edit.title"]!); name value asserted; no keyboard"
        ])
        editor.terminate()

        let completed = launch(sets: 4, current: 4)
        verifyPremium(completed)
        closeTip(completed, required: false)
        completed.descendants(matching: .any)["startRestButton"].tap()
        XCTAssertTrue(completed.staticTexts[chrome["workout.completed"]!].waitForExistence(timeout: 5))
        // The real completion resets after two seconds: no snapshot helper delay.
        let immediate = completed.screenshot()
        try capture("05_TrainingCompleted", completed, assertions: [
            "Actual public button completed set 4 of 4; localized completion asserted: \(chrome["workout.completed"]!)",
            "Immediate native app.screenshot before automatic reset; no delayed snapshot helper"
        ], screenshot: immediate)
        completed.terminate()
    }
}
#endif
