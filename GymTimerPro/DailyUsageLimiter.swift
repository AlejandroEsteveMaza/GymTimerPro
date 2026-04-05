import Combine
import Foundation

@MainActor
final class DailyUsageLimiter: ObservableObject {
    struct Status: Equatable {
        let consumedToday: Int
        let dailyLimit: Int

        var remainingToday: Int { max(0, dailyLimit - consumedToday) }
        var isLimitReached: Bool { consumedToday >= dailyLimit }
    }

    @Published private(set) var status: Status

    private let storage: UserDefaults
    private let calendar: Calendar

    private enum Keys {
        static let dayStart = "usageLimiter.dayStart"
        static let consumed = "usageLimiter.consumed"
    }

    init(
        dailyLimit: Int,
        storage: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.storage = storage
        self.calendar = calendar
        self.status = Status(consumedToday: 0, dailyLimit: max(0, dailyLimit))
        refresh(now: .now)
    }

    func refresh(now: Date) {
        let boundary = resetBoundary(for: now)
        let storedStart = storage.object(forKey: Keys.dayStart) as? Date

        if storedStart != boundary {
            storage.set(boundary, forKey: Keys.dayStart)
            storage.set(0, forKey: Keys.consumed)
        }

        let consumed = max(0, storage.integer(forKey: Keys.consumed))
        status = Status(consumedToday: consumed, dailyLimit: status.dailyLimit)
    }

    /// Returns the most recent 2:00 AM boundary that has already passed.
    private func resetBoundary(for date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let twoAM = calendar.date(byAdding: .hour, value: 2, to: startOfDay)!
        if date < twoAM {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay)!
            return calendar.date(byAdding: .hour, value: 2, to: yesterday)!
        }
        return twoAM
    }

    func canConsume(now: Date, isPro: Bool) -> Bool {
        if isPro { return true }
        refresh(now: now)
        return !status.isLimitReached
    }

    func consume(now: Date, isPro: Bool) {
        guard !isPro else { return }
        refresh(now: now)
        guard !status.isLimitReached else { return }
        let newValue = status.consumedToday + 1
        storage.set(newValue, forKey: Keys.consumed)
        status = Status(consumedToday: newValue, dailyLimit: status.dailyLimit)
    }
}
