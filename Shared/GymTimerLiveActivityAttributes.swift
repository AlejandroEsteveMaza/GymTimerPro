import ActivityKit
import Foundation

enum TimerDisplayFormat: Int, Codable, Hashable, CaseIterable, Sendable {
    case seconds = 0
    case minutesAndSeconds = 1

    static let appStorageKey = "timer.display_format"
}

enum PowerSavingMode: Int, Codable, Hashable, CaseIterable, Sendable {
    case off = 0
    case automatic = 1
    case on = 2

    static let appStorageKey = "energy_saving.mode"

    func isEnabled(systemLowPowerMode: Bool) -> Bool {
        switch self {
        case .off:
            return false
        case .automatic:
            return systemLowPowerMode
        case .on:
            return true
        }
    }
}

enum WeightUnitPreference: Int, Codable, Hashable, CaseIterable, Sendable {
    case automatic = 0
    case kilograms = 1
    case pounds = 2

    static let appStorageKey = "weight.unit_preference"

    func resolvedUnit(locale: Locale = .autoupdatingCurrent) -> UnitMass {
        switch self {
        case .automatic:
            if locale.measurementSystem == .us || locale.measurementSystem == .uk {
                return .pounds
            }
            return .kilograms
        case .kilograms:
            return .kilograms
        case .pounds:
            return .pounds
        }
    }
}

enum RestIncrementPreference: Int, Codable, Hashable, CaseIterable, Sendable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15

    static let appStorageKey = "training.rest_increment"

    var step: Int {
        rawValue
    }
}

enum MaxSetsPreference: Int, Codable, Hashable, CaseIterable, Sendable {
    case ten = 10
    case fifteen = 15
    case twenty = 20
    case thirty = 30

    static let appStorageKey = "training.max_sets"

    var maxSets: Int {
        rawValue
    }
}

enum TimerDisplayFormatter {
    static func string(from totalSeconds: Int, format: TimerDisplayFormat) -> String {
        let clampedSeconds = max(0, totalSeconds)
        switch format {
        case .seconds:
            return "\(clampedSeconds)"
        case .minutesAndSeconds:
            let minutes = clampedSeconds / 60
            let seconds = clampedSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    static func minutesAndSeconds(from totalSeconds: Int) -> (minutes: Int, seconds: Int) {
        let clampedSeconds = max(0, totalSeconds)
        return (clampedSeconds / 60, clampedSeconds % 60)
    }
}

struct GymTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentSet: Int
        var totalSets: Int
        var endDate: Date
        var mode: Mode

        init(
            currentSet: Int,
            totalSets: Int,
            endDate: Date,
            mode: Mode
        ) {
            self.currentSet = currentSet
            self.totalSets = totalSets
            self.endDate = endDate
            self.mode = mode
        }
    }

    enum Mode: String, Codable, Hashable {
        case resting
        case training
    }

    let sessionID: UUID
}
