//
//  Routine.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import Foundation
import SwiftData

@Model
final class Routine: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var totalSets: Int
    var reps: Int = 10
    var restSeconds: Int
    var weightKg: Double?
    @Relationship(deleteRule: .nullify, inverse: \RoutineClassification.routines) var classifications: [RoutineClassification] = []
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        totalSets: Int,
        reps: Int,
        restSeconds: Int,
        weightKg: Double?,
        classifications: [RoutineClassification] = []
    ) {
        self.id = id
        self.name = name
        self.totalSets = totalSets
        self.reps = reps
        self.restSeconds = restSeconds
        self.weightKg = weightKg
        self.classifications = classifications
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
