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

struct ProgressChartBucket: Identifiable, Hashable, Sendable {
    let id: Date
    let startDate: Date
    let workouts: Int
}

struct ProgressPeriodSummary: Hashable, Sendable {
    let workouts: Int
    let activeDays: Int
    let mostRepeatedRoutineName: String?
    let topClassificationName: String?
    let workoutBuckets: [ProgressChartBucket]

    static let empty = ProgressPeriodSummary(
        workouts: 0,
        activeDays: 0,
        mostRepeatedRoutineName: nil,
        topClassificationName: nil,
        workoutBuckets: []
    )
}

struct ProgressBadgeState: Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let isUnlocked: Bool
}

private struct ProgramProgressDerivedData: Sendable {
    let activeWeeklyStreak: Int
    let monthStart: Date
    let monthlyDayCounts: [Date: Int]
    let dayCompletions: [Date: [ProgressCompletionSnapshot]]
    let recentCompletions: [ProgressCompletionSnapshot]
    let badges: [ProgressBadgeState]
    let periodSummaries: [ProgressPeriod: ProgressPeriodSummary]
}

private enum ProgramProgressComputer {
    nonisolated static func compute(
        completions: [ProgressCompletionSnapshot],
        now: Date
    ) -> ProgramProgressDerivedData {
        let calendar = makeCalendar()
        let sortedDesc = completions.sorted { $0.completedAt > $1.completedAt }

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
            streak: activeWeeklyStreak,
            calendar: calendar
        )

        return ProgramProgressDerivedData(
            activeWeeklyStreak: activeWeeklyStreak,
            monthStart: monthStart,
            monthlyDayCounts: monthlyDayCounts,
            dayCompletions: dayCompletions,
            recentCompletions: recentCompletions,
            badges: badges,
            periodSummaries: periodSummaries
        )
    }

    nonisolated private static func makeCalendar() -> Calendar {
        Calendar.autoupdatingCurrent
    }

    nonisolated private static func computeWeeklyStreak(
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

    nonisolated private static func buildPeriodSummary(
        for period: ProgressPeriod,
        completions: [ProgressCompletionSnapshot],
        now: Date,
        calendar: Calendar
    ) -> ProgressPeriodSummary {
        let interval = dateInterval(for: period, now: now, calendar: calendar)
        let filtered = completions.filter { interval.contains($0.completedAt) }

        guard !filtered.isEmpty else {
            let emptyBuckets = makeBucketStarts(for: period, in: interval, calendar: calendar).map {
                ProgressChartBucket(id: $0, startDate: $0, workouts: 0)
            }
            return ProgressPeriodSummary(
                workouts: 0,
                activeDays: 0,
                mostRepeatedRoutineName: nil,
                topClassificationName: nil,
                workoutBuckets: emptyBuckets
            )
        }

        let workouts = filtered.count
        let activeDays = Set(filtered.map { calendar.startOfDay(for: $0.completedAt) }).count

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
            filtered.compactMap { completion -> (Date, Int)? in
                guard let bucketStart = bucketStart(for: completion.completedAt, period: period, calendar: calendar) else {
                    return nil
                }
                return (bucketStart, 1)
            },
            uniquingKeysWith: +
        )

        let buckets = bucketStarts.map { startDate in
            let values = grouped[startDate] ?? 0
            return ProgressChartBucket(
                id: startDate,
                startDate: startDate,
                workouts: values
            )
        }

        return ProgressPeriodSummary(
            workouts: workouts,
            activeDays: activeDays,
            mostRepeatedRoutineName: topRoutine,
            topClassificationName: topClassification,
            workoutBuckets: buckets
        )
    }

    nonisolated private static func buildBadges(
        completions: [ProgressCompletionSnapshot],
        streak: Int,
        calendar: Calendar
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
                isUnlocked: has3InAnyWeek
            ),
            ProgressBadgeState(
                id: "streak_4",
                titleKey: "progress.badge.streak_4.title",
                subtitleKey: "progress.badge.streak_4.subtitle",
                isUnlocked: streak >= 4
            )
        ]
    }

    nonisolated private static func hasAtLeastThreeWorkoutsInAWeek(
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

    nonisolated private static func dateInterval(for period: ProgressPeriod, now: Date, calendar: Calendar) -> DateInterval {
        let todayStart = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        switch period {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
            return DateInterval(start: start, end: tomorrow)
        case .fortnight:
            let start = calendar.date(byAdding: .day, value: -14, to: todayStart) ?? todayStart
            return DateInterval(start: start, end: tomorrow)
        case .month:
            return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
        case .quarter:
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: todayStart)?.start ?? todayStart
            let start = calendar.date(byAdding: .weekOfYear, value: -11, to: currentWeekStart) ?? currentWeekStart
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? tomorrow
            return DateInterval(start: start, end: end)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: tomorrow) ?? now
            return DateInterval(start: start, end: tomorrow)
        }
    }

    nonisolated private static func makeBucketStarts(
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
        case .month:
            var values: [Date] = []
            var pointer = calendar.dateInterval(of: .weekOfYear, for: interval.start)?.start ?? interval.start
            while pointer < interval.end {
                values.append(pointer)
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: pointer) else { break }
                pointer = next
            }
            return values
        case .quarter:
            var values: [Date] = []
            var pointer = calendar.dateInterval(of: .weekOfYear, for: interval.start)?.start ?? interval.start
            for _ in 0 ..< 12 {
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

    nonisolated private static func bucketStart(
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
    private(set) var activeWeeklyStreak = 0
    private(set) var monthStart = Calendar.autoupdatingCurrent.startOfDay(for: .now)
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

    func completions(on day: Date) -> [ProgressCompletionSnapshot] {
        let calendar = Calendar.autoupdatingCurrent
        let dayStart = calendar.startOfDay(for: day)
        return dayCompletions[dayStart] ?? []
    }

    func reload(completions: [WorkoutCompletion], now: Date = .now) async {
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

        let newSignature = signatureFor(snapshots: snapshots)
        guard newSignature != signature else { return }

        signature = newSignature
        isLoading = true

        let derived = await Task.detached(priority: .userInitiated) {
            ProgramProgressComputer.compute(
                completions: snapshots,
                now: now
            )
        }.value

        activeWeeklyStreak = derived.activeWeeklyStreak
        monthStart = derived.monthStart
        monthlyDayCounts = derived.monthlyDayCounts
        dayCompletions = derived.dayCompletions
        recentCompletions = derived.recentCompletions
        badges = derived.badges
        periodSummaries = derived.periodSummaries
        isLoading = false
    }

    private func signatureFor(snapshots: [ProgressCompletionSnapshot]) -> String {
        let first = snapshots.first
        let last = snapshots.last
        return [
            "\(snapshots.count)",
            first?.id.uuidString ?? "none",
            "\(first?.completedAt.timeIntervalSince1970 ?? 0)",
            last?.id.uuidString ?? "none",
            "\(last?.completedAt.timeIntervalSince1970 ?? 0)"
        ].joined(separator: "|")
    }
}
