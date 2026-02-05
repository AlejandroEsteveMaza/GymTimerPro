//
//  WorkoutCompletion.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 05/02/26.
//

import Foundation
import SwiftData

@Model
final class WorkoutCompletion: Identifiable {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var routineID: UUID?
    var routineNameSnapshot: String
    var classificationID: UUID?
    var classificationNameSnapshot: String?
    var durationSeconds: Int?
    var notes: String?

    init(
        id: UUID = UUID(),
        completedAt: Date = .now,
        routineID: UUID? = nil,
        routineNameSnapshot: String = "",
        classificationID: UUID? = nil,
        classificationNameSnapshot: String? = nil,
        durationSeconds: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.routineID = routineID
        self.routineNameSnapshot = routineNameSnapshot
        self.classificationID = classificationID
        self.classificationNameSnapshot = classificationNameSnapshot
        self.durationSeconds = durationSeconds
        self.notes = notes
    }
}
