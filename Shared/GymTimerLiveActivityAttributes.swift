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
        var timerDisplayFormatRawValue: Int?

        var timerDisplayFormat: TimerDisplayFormat {
            TimerDisplayFormat(rawValue: timerDisplayFormatRawValue ?? TimerDisplayFormat.seconds.rawValue) ?? .seconds
        }

        init(
            currentSet: Int,
            totalSets: Int,
            endDate: Date,
            mode: Mode,
            timerDisplayFormatRawValue: Int? = nil
        ) {
            self.currentSet = currentSet
            self.totalSets = totalSets
            self.endDate = endDate
            self.mode = mode
            self.timerDisplayFormatRawValue = timerDisplayFormatRawValue
        }
    }

    enum Mode: String, Codable, Hashable {
        case resting
        case training
    }

    let sessionID: UUID
}
