import XCTest
@testable import GymTimerPro

final class PaywallCopyTests: XCTestCase {
    func testBulletsCountIsScannableAcrossLevels() {
        for infoLevel in [PaywallInfoLevel.light, .standard, .detailed] {
            let proCopy = PaywallCopy.make(entryPoint: .proModule, infoLevel: infoLevel)
            let limitCopy = PaywallCopy.make(entryPoint: .dailyLimitDuringWorkout, infoLevel: infoLevel)

            XCTAssertLessThanOrEqual(proCopy.bullets.count, 3)
            XCTAssertLessThanOrEqual(limitCopy.bullets.count, 3)
            XCTAssertFalse(proCopy.title.isEmpty)
            XCTAssertFalse(limitCopy.title.isEmpty)
        }
    }

    func testEntryPointVariantsUseDifferentHeadlineTone() {
        for infoLevel in [PaywallInfoLevel.light, .standard, .detailed] {
            let proCopy = PaywallCopy.make(entryPoint: .proModule, infoLevel: infoLevel)
            let limitCopy = PaywallCopy.make(entryPoint: .dailyLimitDuringWorkout, infoLevel: infoLevel)

            XCTAssertNotEqual(proCopy.title, limitCopy.title)
            XCTAssertNotEqual(proCopy.subtitle, limitCopy.subtitle)
        }
    }

    func testDefaultPlanSelectionPrefersAnnual() {
        let ids = [PurchaseManager.monthlyProductID, PurchaseManager.annualProductID]
        let defaultID = PaywallPlanDefaults.defaultProductID(availableIDs: ids)
        XCTAssertEqual(defaultID, PurchaseManager.annualProductID)
    }

    func testDefaultPlanFallsBackToFirstAvailable() {
        let ids = [PurchaseManager.monthlyProductID]
        let defaultID = PaywallPlanDefaults.defaultProductID(availableIDs: ids)
        XCTAssertEqual(defaultID, PurchaseManager.monthlyProductID)
    }
}
