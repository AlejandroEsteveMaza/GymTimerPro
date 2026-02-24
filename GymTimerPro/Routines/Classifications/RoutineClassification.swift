//
//  RoutineClassification.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import Foundation
import SwiftData

@Model
final class RoutineClassification: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var normalizedName: String
    var routines: [Routine] = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.normalizedName = RoutineClassification.normalize(name)
    }

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
