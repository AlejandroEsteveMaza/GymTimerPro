import Foundation
import XCTest

// MARK: - Deterministic clock and storage

protocol Clock {
    var now: Date { get }
}

final class TestClock: Clock {
    var now: Date
    init(now: Date) { self.now = now }
}

protocol UsageStorage: AnyObject {
    var lastDayID: Int { get set } // -1 means uninitialized
    var consumed: Int { get set }
}

final class InMemoryStorage: UsageStorage {
    var lastDayID: Int = -1
    var consumed: Int = 0
}

// MARK: - Free mode limiter (anti-exploit)

/// Day is defined by the injected `calendar` at init time (its timeZone is anchored for anti-exploit). To switch to UTC/server day, pass a calendar with `timeZone = .gmt`.
final class FreeModeLimiter {
    private let dailyLimit: Int
    private let clock: Clock
    private let storage: UsageStorage
    private let dayCalendar: Calendar

    init(dailyLimit: Int = 19, clock: Clock, calendar: Calendar, storage: UsageStorage) {
        self.dailyLimit = dailyLimit
        self.clock = clock
        self.storage = storage
        var anchoredCalendar = calendar
        anchoredCalendar.timeZone = calendar.timeZone
        self.dayCalendar = anchoredCalendar
        if storage.lastDayID == -1 {
            storage.lastDayID = dayID(for: clock.now)
        }
        refresh()
    }

    func canConsume() -> Bool {
        refresh()
        return storage.consumed < dailyLimit
    }

    @discardableResult
    func consume() -> Bool {
        refresh()
        guard storage.consumed < dailyLimit else { return false }
        storage.consumed += 1
        return true
    }

    func remainingQuota() -> Int {
        refresh()
        return max(0, dailyLimit - storage.consumed)
    }

    private func refresh() {
        let today = dayID(for: clock.now)
        if today > storage.lastDayID { // anti-exploit: only resets when the day strictly advances
            storage.lastDayID = today
            storage.consumed = 0
        }
    }

    private func dayID(for date: Date) -> Int {
        let comps = dayCalendar.dateComponents(in: dayCalendar.timeZone, from: date)
        return (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
    }
}

// MARK: - Tests

final class FreeModeLimiterTests: XCTestCase {
    private func makeLimiter(
        limit: Int = 3,
        clock: TestClock,
        timeZoneID: String = "Europe/Madrid",
        storage: UsageStorage = InMemoryStorage()
    ) -> FreeModeLimiter {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZoneID)!
        return FreeModeLimiter(dailyLimit: limit, clock: clock, calendar: cal, storage: storage)
    }

    func testResetsWhenCrossingMidnightForwardOnly() {
        let clock = TestClock(now: iso("2024-03-30T23:59:59+01:00")) // Madrid
        let limiter = makeLimiter(limit: 3, clock: clock)
        XCTAssertTrue(limiter.consume())
        XCTAssertEqual(limiter.remainingQuota(), 2)

        clock.now = iso("2024-03-31T03:00:01+02:00") // crosses day + DST jump (+1h at 02:00)
        XCTAssertTrue(limiter.consume())               // reset applied
        XCTAssertEqual(limiter.remainingQuota(), 2)    // new day, 1 used
    }

    func testNoDoubleResetWhenClockMovesBackwards() {
        let storage = InMemoryStorage()
        let clock = TestClock(now: iso("2024-04-01T23:50:00+02:00"))
        let limiter = makeLimiter(limit: 2, clock: clock, storage: storage)
        XCTAssertTrue(limiter.consume())
        XCTAssertTrue(limiter.consume())
        XCTAssertFalse(limiter.consume())              // limit reached for day 1

        clock.now = iso("2024-04-02T00:05:00+02:00")   // next day
        XCTAssertTrue(limiter.consume())               // reset once
        XCTAssertEqual(limiter.remainingQuota(), 1)

        clock.now = iso("2024-04-01T22:00:00+02:00")   // clock set back
        XCTAssertTrue(limiter.consume())               // consumes remaining slot
        XCTAssertFalse(limiter.consume())              // no second reset allowed
    }

    func testTimezoneChangeDoesNotGrantExtraQuota() {
        let storage = InMemoryStorage()
        let clock = TestClock(now: iso("2024-06-15T21:00:00+02:00")) // Madrid
        var limiter = makeLimiter(limit: 2, clock: clock, storage: storage)
        XCTAssertTrue(limiter.consume())
        XCTAssertTrue(limiter.consume())
        XCTAssertFalse(limiter.consume())

        // Same absolute instant; timezone change makes local date appear earlier, but day is anchored -> no reset.
        clock.now = iso("2024-06-15T12:00:00-07:00") // Los Angeles (same instant as 21:00 Madrid)
        XCTAssertFalse(limiter.consume())             // no reset granted

        // Advance to a truly new day in anchored calendar: allow a single reset.
        clock.now = iso("2024-06-16T01:00:00-07:00")
        XCTAssertTrue(limiter.consume())
        XCTAssertTrue(limiter.consume())
        XCTAssertFalse(limiter.consume())
    }

    func testAntiExploitForwardResetThenBackwardAndTimezoneTricks() {
        let storage = InMemoryStorage()
        let clock = TestClock(now: iso("2024-07-01T23:59:50+02:00")) // Madrid
        var limiter = makeLimiter(limit: 3, clock: clock, storage: storage)
        XCTAssertTrue(limiter.consume())
        XCTAssertTrue(limiter.consume())
        XCTAssertTrue(limiter.consume())
        XCTAssertFalse(limiter.consume())               // day 1 full

        // Legit reset on the next day
        clock.now = iso("2024-07-02T00:05:00+02:00")
        XCTAssertTrue(limiter.consume())                // reset applied once
        XCTAssertEqual(limiter.remainingQuota(), 2)

        // Clock backwards: must NOT reset again
        clock.now = iso("2024-07-01T22:00:00+02:00")
        XCTAssertTrue(limiter.consume())                // consumes remaining slots
        XCTAssertTrue(limiter.consume())
        XCTAssertFalse(limiter.consume())               // still capped

        // Timezone jump attempt (same absolute instant as previous step, expressed in a future zone): no reset
        clock.now = iso("2024-07-02T08:00:00+12:00")    // same as 2024-07-01T22:00:00+02:00
        XCTAssertFalse(limiter.consume())               // still capped

        // Legit next day in anchored calendar -> single reset allowed
        clock.now = iso("2024-07-03T06:00:00+02:00")
        XCTAssertTrue(limiter.consume())
    }

    // MARK: - Helpers

    private func iso(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: string) else {
            fatalError("Invalid ISO date: \(string)")
        }
        return date
    }
}
