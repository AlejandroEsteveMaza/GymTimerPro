import ActivityKit
import Foundation

struct GymTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentSet: Int
        var totalSets: Int
        var endDate: Date
        var mode: Mode
    }

    enum Mode: String, Codable, Hashable {
        case resting
        case training
    }

    let sessionID: UUID
}
