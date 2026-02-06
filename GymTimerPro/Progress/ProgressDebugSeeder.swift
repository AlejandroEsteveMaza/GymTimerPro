//
//  ProgressDebugSeeder.swift
//  GymTimerPro
//
//  DEBUG-only seed utilities for Progress UI testing.
//

#if DEBUG
import Foundation
import OSLog
import SwiftData

@MainActor
enum ProgressDebugSeeder {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GymTimerPro",
        category: "ProgressSeed"
    )

    private static let resetArg = "seed-progress-reset"
    private static let profileYearHeavy = "seed-progress-year-heavy"

    static func runIfNeeded(modelContainer: ModelContainer) {
        let args = Set(ProcessInfo.processInfo.arguments.map { $0.lowercased() })
        let shouldReset = args.contains(resetArg)
        let shouldSeedYearHeavy = args.contains(profileYearHeavy)

        guard shouldReset || shouldSeedYearHeavy else { return }

        let context = modelContainer.mainContext

        if shouldReset {
            deleteAllWorkoutCompletions(in: context)
        }

        if shouldSeedYearHeavy {
            seedYearHeavyIfNeeded(in: context, force: shouldReset)
        }
    }

    private static func deleteAllWorkoutCompletions(in context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<WorkoutCompletion>())
            guard !all.isEmpty else { return }
            all.forEach { context.delete($0) }
            try context.save()
            logger.info("Deleted \(all.count, privacy: .public) WorkoutCompletion records (seed reset).")
        } catch {
            logger.error("Failed to delete WorkoutCompletion during seed reset: \(String(describing: error))")
        }
    }

    private static func seedYearHeavyIfNeeded(in context: ModelContext, force: Bool) {
        let marker = profileYearHeavy

        if !force {
            do {
                let predicate = #Predicate<WorkoutCompletion> { completion in
                    completion.notes == marker
                }
                let existing = try context.fetchCount(FetchDescriptor(predicate: predicate))
                if existing > 0 {
                    logger.info("Seed \(marker, privacy: .public) skipped (already seeded).")
                    return
                }
            } catch {
                logger.error("Failed to check existing seed markers: \(String(describing: error))")
            }
        }

        let calendar = Calendar(identifier: .gregorian)
        let todayStart = calendar.startOfDay(for: .now)

        // Deterministic, realistic-ish dataset:
        // - Rolling 365 days back from today (includes today).
        // - 0-2 completions per day with a bias towards 3-5 workouts/week.
        var rng = SeededRNG(seed: 0xC0FFEE)

        let routineNames = [
            "Full Body",
            "Empuje",
            "Tiron",
            "Pierna",
            "Torso",
            "Core",
            "HIIT"
        ]
        let classificationNames = [
            "Empuje",
            "Tiron",
            "Pierna",
            "Full Body",
            "Core"
        ]

        var inserted = 0
        for dayOffset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else { continue }

            // Weekday bias: more activity on weekdays, less on weekends.
            let weekday = calendar.component(.weekday, from: day) // 1=Sun ... 7=Sat
            let isWeekend = weekday == 1 || weekday == 7

            let roll = rng.nextInt(0..<100)
            let count: Int
            if isWeekend {
                count = roll < 70 ? 0 : (roll < 95 ? 1 : 2)
            } else {
                count = roll < 45 ? 0 : (roll < 90 ? 1 : 2)
            }

            for _ in 0..<count {
                let hour = rng.nextInt(6..<22)
                let minute = rng.nextInt(0..<60)
                let completedAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day

                let routineName = routineNames[rng.nextInt(0..<routineNames.count)]
                let classificationName = classificationNames[rng.nextInt(0..<classificationNames.count)]
                let durationMinutes = rng.nextInt(25..<80)

                context.insert(
                    WorkoutCompletion(
                        completedAt: completedAt,
                        routineID: nil,
                        routineNameSnapshot: routineName,
                        classificationID: nil,
                        classificationNameSnapshot: classificationName,
                        durationSeconds: durationMinutes * 60,
                        notes: marker
                    )
                )
                inserted += 1
            }
        }

        do {
            try context.save()
            logger.info("Seeded \(inserted, privacy: .public) WorkoutCompletion records for \(marker, privacy: .public).")
        } catch {
            logger.error("Failed to save progress seed \(marker, privacy: .public): \(String(describing: error))")
        }
    }
}

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func nextUInt64() -> UInt64 {
        // Xorshift64*
        state &+= 0x9E3779B97F4A7C15
        var x = state
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        return x ^ (x >> 31)
    }

    mutating func nextInt(_ range: Range<Int>) -> Int {
        let width = max(1, range.count)
        return range.lowerBound + Int(nextUInt64() % UInt64(width))
    }
}
#endif

