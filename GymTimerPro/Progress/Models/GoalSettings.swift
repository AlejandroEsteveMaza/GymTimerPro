//
//  GoalSettings.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 05/02/26.
//

import Foundation
import SwiftData

@Model
final class GoalSettings: Identifiable {
    @Attribute(.unique) var id: UUID
    var weeklyWorkoutsGoal: Int
    var weeklyMinutesGoal: Int
    var startsOnMonday: Bool

    init(
        id: UUID = UUID(),
        weeklyWorkoutsGoal: Int = 3,
        weeklyMinutesGoal: Int = 120,
        startsOnMonday: Bool = true
    ) {
        self.id = id
        self.weeklyWorkoutsGoal = max(1, weeklyWorkoutsGoal)
        self.weeklyMinutesGoal = max(0, weeklyMinutesGoal)
        self.startsOnMonday = startsOnMonday
    }
}
