//
//  ProgramProgressStore.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 05/02/26.
//

import Foundation
import Observation

enum ProgressPeriod: String, CaseIterable, Identifiable {
    case week
    case fortnight
    case month
    case quarter
    case year

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .week: "progress.period.week"
        case .fortnight: "progress.period.fortnight"
        case .month: "progress.period.month"
        case .quarter: "progress.period.quarter"
        case .year: "progress.period.year"
        }
    }
}

struct ProgressCompletionSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let completedAt: Date
    let routineID: UUID?
    let routineName: String
    let classificationID: UUID?
    let classificationName: String?
    let durationSeconds: Int?
}

struct ProgressGoalSnapshot: Hashable, Sendable {
    let weeklyWorkoutsGoal: Int
    let weeklyMinutesGoal: Int
    let startsOnMonday: Bool

    static let `default` = ProgressGoalSnapshot(
        weeklyWorkoutsGoal: 3,
        weeklyMinutesGoal: 120,
        startsOnMonday: true
    )
}

struct ProgressWeekSummary: Hashable, Sendable {
    let workouts: Int
    let minutes: Int
    let activeDays: Int

    static let empty = ProgressWeekSummary(workouts: 0, minutes: 0, activeDays: 0)
}

struct ProgressChartBucket: Identifiable, Hashable, Sendable {
    let id: Date
    let startDate: Date
    let workouts: Int
    let minutes: Int
}

struct ProgressPeriodSummary: Hashable, Sendable {
    let workouts: Int
    let minutes: Int
    let activeDays: Int
    let mostRepeatedRoutineName: String?
    let topClassificationName: String?
    let workoutBuckets: [ProgressChartBucket]
    let hasDurationData: Bool

    static let empty = ProgressPeriodSummary(
        workouts: 0,
        minutes: 0,
        activeDays: 0,
        mostRepeatedRoutineName: nil,
        topClassificationName: nil,
        workoutBuckets: [],
        hasDurationData: false
    )
}

struct ProgressBadgeState: Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let isUnlocked: Bool
}

private struct ProgramProgressDerivedData: Sendable {
    let totalWorkouts: Int
    let weekSummary: ProgressWeekSummary
    let weeklyStreak: Int
    let activeWeeklyStreak: Int
    let monthStart: Date
    let monthlyDayCounts: [Date: Int]
    let dayCompletions: [Date: [ProgressCompletionSnapshot]]
    let recentCompletions: [ProgressCompletionSnapshot]
    let badges: [ProgressBadgeState]
    let periodSummaries: [ProgressPeriod: ProgressPeriodSummary]
}

private enum ProgramProgressComputer {
    static func compute(
        completions: [ProgressCompletionSnapshot],
        goal: ProgressGoalSnapshot,
        now: Date
    ) -> ProgramProgressDerivedData {
        let calendar = makeCalendar(startsOnMonday: goal.startsOnMonday)
        let sortedDesc = completions.sorted { $0.completedAt > $1.completedAt }

        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        let weekCompletions = sortedDesc.filter { weekInterval.contains($0.completedAt) }
        let weekSummary = ProgressWeekSummary(
            workouts: weekCompletions.count,
            minutes: weekCompletions.compactMap(\.durationSeconds).reduce(0, +) / 60,
            activeDays: Set(weekCompletions.map { calendar.startOfDay(for: $0.completedAt) }).count
        )

        let weeklyGoalStreak = computeWeeklyStreak(
            completions: sortedDesc,
            calendar: calendar,
            now: now,
            goal: max(1, goal.weeklyWorkoutsGoal)
        )
        let activeWeeklyStreak = computeWeeklyStreak(
            completions: sortedDesc,
            calendar: calendar,
            now: now,
            goal: 1
        )

        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let monthInterval = DateInterval(start: monthStart, end: monthEnd)

        var monthlyDayCounts: [Date: Int] = [:]
        var dayCompletions: [Date: [ProgressCompletionSnapshot]] = [:]
        for completion in sortedDesc {
            let dayStart = calendar.startOfDay(for: completion.completedAt)
            dayCompletions[dayStart, default: []].append(completion)
            if monthInterval.contains(completion.completedAt) {
                monthlyDayCounts[dayStart, default: 0] += 1
            }
        }

        let recentCompletions = Array(sortedDesc.prefix(30))
        let periodSummaries = Dictionary(
            uniqueKeysWithValues: ProgressPeriod.allCases.map { period in
                (period, buildPeriodSummary(for: period, completions: sortedDesc, now: now, calendar: calendar))
            }
        )
        let badges = buildBadges(
            completions: sortedDesc,
            weekSummary: weekSummary,
            streak: weeklyGoalStreak,
            goal: max(1, goal.weeklyWorkoutsGoal),
            calendar: calendar,
            now: now
        )

        return ProgramProgressDerivedData(
            totalWorkouts: sortedDesc.count,
            weekSummary: weekSummary,
            weeklyStreak: weeklyGoalStreak,
            activeWeeklyStreak: activeWeeklyStreak,
            monthStart: monthStart,
            monthlyDayCounts: monthlyDayCounts,
            dayCompletions: dayCompletions,
            recentCompletions: recentCompletions,
            badges: badges,
            periodSummaries: periodSummaries
        )
    }

    private static func makeCalendar(startsOnMonday: Bool) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.current
        calendar.firstWeekday = startsOnMonday ? 2 : 1
        return calendar
    }

    private static func computeWeeklyStreak(
        completions: [ProgressCompletionSnapshot],
        calendar: Calendar,
        now: Date,
        goal: Int
    ) -> Int {
        let countsByWeek = Dictionary(
            completions.compactMap { completion -> (Date, Int)? in
                guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: completion.completedAt)?.start else {
                    return nil
                }
                return (weekStart, 1)
            },
            uniquingKeysWith: +
        )

        guard var pointer = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        var streak = 0
        while countsByWeek[pointer, default: 0] >= goal {
            streak += 1
            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: pointer) else { break }
            pointer = previousWeek
        }
        return streak
    }

    private static func buildPeriodSummary(
        for period: ProgressPeriod,
        completions: [ProgressCompletionSnapshot],
        now: Date,
        calendar: Calendar
    ) -> ProgressPeriodSummary {
        let interval = dateInterval(for: period, now: now, calendar: calendar)
        let filtered = completions.filter { interval.contains($0.completedAt) }

        guard !filtered.isEmpty else {
            let emptyBuckets = makeBucketStarts(for: period, in: interval, calendar: calendar).map {
                ProgressChartBucket(id: $0, startDate: $0, workouts: 0, minutes: 0)
            }
            return ProgressPeriodSummary(
                workouts: 0,
                minutes: 0,
                activeDays: 0,
                mostRepeatedRoutineName: nil,
                topClassificationName: nil,
                workoutBuckets: emptyBuckets,
                hasDurationData: false
            )
        }

        let workouts = filtered.count
        let minutes = filtered.compactMap(\.durationSeconds).reduce(0, +) / 60
        let activeDays = Set(filtered.map { calendar.startOfDay(for: $0.completedAt) }).count
        let hasDurationData = filtered.contains { ($0.durationSeconds ?? 0) > 0 }

        let routineCounts = Dictionary(
            filtered.map { ($0.routineName, 1) },
            uniquingKeysWith: +
        )
        let topRoutine = routineCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .first?
            .key

        let classificationCounts = Dictionary(
            filtered.compactMap { completion -> (String, Int)? in
                guard let name = completion.classificationName else { return nil }
                return (name, 1)
            },
            uniquingKeysWith: +
        )
        let topClassification = classificationCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .first?
            .key

        let bucketStarts = makeBucketStarts(for: period, in: interval, calendar: calendar)
        let grouped = Dictionary(
            filtered.compactMap { completion -> (Date, (Int, Int))? in
                guard let bucketStart = bucketStart(for: completion.completedAt, period: period, calendar: calendar) else {
                    return nil
                }
                return (bucketStart, (1, completion.durationSeconds ?? 0))
            },
            uniquingKeysWith: { lhs, rhs in
                (lhs.0 + rhs.0, lhs.1 + rhs.1)
            }
        )

        let buckets = bucketStarts.map { startDate in
            let values = grouped[startDate] ?? (0, 0)
            return ProgressChartBucket(
                id: startDate,
                startDate: startDate,
                workouts: values.0,
                minutes: values.1 / 60
            )
        }

        return ProgressPeriodSummary(
            workouts: workouts,
            minutes: minutes,
            activeDays: activeDays,
            mostRepeatedRoutineName: topRoutine,
            topClassificationName: topClassification,
            workoutBuckets: buckets,
            hasDurationData: hasDurationData
        )
    }

    private static func buildBadges(
        completions: [ProgressCompletionSnapshot],
        weekSummary: ProgressWeekSummary,
        streak: Int,
        goal: Int,
        calendar: Calendar,
        now: Date
    ) -> [ProgressBadgeState] {
        let total = completions.count
        let has3InAnyWeek = hasAtLeastThreeWorkoutsInAWeek(completions: completions, calendar: calendar)

        return [
            ProgressBadgeState(
                id: "first_workout",
                titleKey: "progress.badge.first_workout.title",
                subtitleKey: "progress.badge.first_workout.subtitle",
                isUnlocked: total >= 1
            ),
            ProgressBadgeState(
                id: "workouts_5",
                titleKey: "progress.badge.workouts_5.title",
                subtitleKey: "progress.badge.workouts_5.subtitle",
                isUnlocked: total >= 5
            ),
            ProgressBadgeState(
                id: "workouts_10",
                titleKey: "progress.badge.workouts_10.title",
                subtitleKey: "progress.badge.workouts_10.subtitle",
                isUnlocked: total >= 10
            ),
            ProgressBadgeState(
                id: "workouts_25",
                titleKey: "progress.badge.workouts_25.title",
                subtitleKey: "progress.badge.workouts_25.subtitle",
                isUnlocked: total >= 25
            ),
            ProgressBadgeState(
                id: "three_week",
                titleKey: "progress.badge.three_week.title",
                subtitleKey: "progress.badge.three_week.subtitle",
                isUnlocked: has3InAnyWeek || weekSummary.workouts >= 3
            ),
            ProgressBadgeState(
                id: "streak_4",
                titleKey: "progress.badge.streak_4.title",
                subtitleKey: "progress.badge.streak_4.subtitle",
                isUnlocked: streak >= 4
            ),
            ProgressBadgeState(
                id: "goal_week",
                titleKey: "progress.badge.goal_week.title",
                subtitleKey: "progress.badge.goal_week.subtitle",
                isUnlocked: weekSummary.workouts >= goal
            )
        ]
    }

    private static func hasAtLeastThreeWorkoutsInAWeek(
        completions: [ProgressCompletionSnapshot],
        calendar: Calendar
    ) -> Bool {
        let counts = Dictionary(
            completions.compactMap { completion -> (Date, Int)? in
                guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: completion.completedAt)?.start else {
                    return nil
                }
                return (weekStart, 1)
            },
            uniquingKeysWith: +
        )
        return counts.values.contains(where: { $0 >= 3 })
    }

    private static func dateInterval(for period: ProgressPeriod, now: Date, calendar: Calendar) -> DateInterval {
        switch period {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        case .fortnight:
            let end = (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now)
            let start = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now)) ?? now
            return DateInterval(start: start, end: end)
        case .month:
            return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
        case .quarter:
            let end = (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now)
            let start = calendar.date(byAdding: .month, value: -3, to: end) ?? now
            return DateInterval(start: start, end: end)
        case .year:
            let end = (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now)
            let start = calendar.date(byAdding: .year, value: -1, to: end) ?? now
            return DateInterval(start: start, end: end)
        }
    }

    private static func makeBucketStarts(
        for period: ProgressPeriod,
        in interval: DateInterval,
        calendar: Calendar
    ) -> [Date] {
        switch period {
        case .week, .fortnight:
            var values: [Date] = []
            var pointer = calendar.startOfDay(for: interval.start)
            while pointer < interval.end {
                values.append(pointer)
                guard let next = calendar.date(byAdding: .day, value: 1, to: pointer) else { break }
                pointer = next
            }
            return values
        case .month, .quarter:
            var values: [Date] = []
            var pointer = calendar.dateInterval(of: .weekOfYear, for: interval.start)?.start ?? interval.start
            while pointer < interval.end {
                values.append(pointer)
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: pointer) else { break }
                pointer = next
            }
            return values
        case .year:
            var values: [Date] = []
            var pointer = calendar.dateInterval(of: .month, for: interval.start)?.start ?? interval.start
            while pointer < interval.end {
                values.append(pointer)
                guard let next = calendar.date(byAdding: .month, value: 1, to: pointer) else { break }
                pointer = next
            }
            return values
        }
    }

    private static func bucketStart(
        for date: Date,
        period: ProgressPeriod,
        calendar: Calendar
    ) -> Date? {
        switch period {
        case .week, .fortnight:
            return calendar.startOfDay(for: date)
        case .month, .quarter:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
        case .year:
            return calendar.dateInterval(of: .month, for: date)?.start
        }
    }
}

@MainActor
@Observable
final class ProgramProgressStore {
    private(set) var goal = ProgressGoalSnapshot.default
    private(set) var totalWorkouts = 0
    private(set) var weekSummary = ProgressWeekSummary.empty
    private(set) var weeklyStreak = 0
    private(set) var activeWeeklyStreak = 0
    private(set) var monthStart = Calendar.current.startOfDay(for: .now)
    private(set) var monthlyDayCounts: [Date: Int] = [:]
    private(set) var recentCompletions: [ProgressCompletionSnapshot] = []
    private(set) var badges: [ProgressBadgeState] = []
    private(set) var isLoading = false

    private var signature = ""
    private var dayCompletions: [Date: [ProgressCompletionSnapshot]] = [:]
    private var periodSummaries: [ProgressPeriod: ProgressPeriodSummary] = [:]

    func summary(for period: ProgressPeriod) -> ProgressPeriodSummary {
        periodSummaries[period] ?? .empty
    }

    func completions(on day: Date, startsOnMonday: Bool) -> [ProgressCompletionSnapshot] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = startsOnMonday ? 2 : 1
        let dayStart = calendar.startOfDay(for: day)
        return dayCompletions[dayStart] ?? []
    }

    func goalMessage() -> String {
        let remaining = max(goal.weeklyWorkoutsGoal - weekSummary.workouts, 0)
        if remaining == 0 {
            return L10n.tr("progress.goal.message.completed")
        }
        if remaining == 1 {
            return L10n.tr("progress.goal.message.one_left")
        }
        return L10n.format("progress.goal.message.many_left_format", remaining)
    }

    func reload(completions: [WorkoutCompletion], goalSettings: GoalSettings?, now: Date = .now) async {
        let goalSnapshot = ProgressGoalSnapshot(
            weeklyWorkoutsGoal: max(1, goalSettings?.weeklyWorkoutsGoal ?? 3),
            weeklyMinutesGoal: max(0, goalSettings?.weeklyMinutesGoal ?? 120),
            startsOnMonday: goalSettings?.startsOnMonday ?? true
        )

        let snapshots = completions.map { completion in
            ProgressCompletionSnapshot(
                id: completion.id,
                completedAt: completion.completedAt,
                routineID: completion.routineID,
                routineName: completion.routineNameSnapshot.isEmpty
                    ? L10n.tr("progress.quick_workout_name")
                    : completion.routineNameSnapshot,
                classificationID: completion.classificationID,
                classificationName: completion.classificationNameSnapshot,
                durationSeconds: completion.durationSeconds
            )
        }
        .sorted { $0.completedAt > $1.completedAt }

        let newSignature = signatureFor(snapshots: snapshots, goal: goalSnapshot)
        guard newSignature != signature else { return }

        signature = newSignature
        isLoading = true

        let derived = await Task.detached(priority: .userInitiated) {
            ProgramProgressComputer.compute(
                completions: snapshots,
                goal: goalSnapshot,
                now: now
            )
        }.value

        goal = goalSnapshot
        totalWorkouts = derived.totalWorkouts
        weekSummary = derived.weekSummary
        weeklyStreak = derived.weeklyStreak
        activeWeeklyStreak = derived.activeWeeklyStreak
        monthStart = derived.monthStart
        monthlyDayCounts = derived.monthlyDayCounts
        dayCompletions = derived.dayCompletions
        recentCompletions = derived.recentCompletions
        badges = derived.badges
        periodSummaries = derived.periodSummaries
        isLoading = false
    }

    private func signatureFor(
        snapshots: [ProgressCompletionSnapshot],
        goal: ProgressGoalSnapshot
    ) -> String {
        let first = snapshots.first
        let last = snapshots.last
        return [
            "\(snapshots.count)",
            first?.id.uuidString ?? "none",
            "\(first?.completedAt.timeIntervalSince1970 ?? 0)",
            last?.id.uuidString ?? "none",
            "\(last?.completedAt.timeIntervalSince1970 ?? 0)",
            "\(goal.weeklyWorkoutsGoal)",
            "\(goal.weeklyMinutesGoal)",
            "\(goal.startsOnMonday)"
        ].joined(separator: "|")
    }
}
