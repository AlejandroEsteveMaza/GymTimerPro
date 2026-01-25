//
//  RoutineSelectionStore.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import Combine
import Foundation

@MainActor
final class RoutineSelectionStore: ObservableObject {
    struct Selection: Equatable {
        let id: UUID
        let name: String
        let totalSets: Int
        let reps: Int
        let restSeconds: Int
    }

    @Published private(set) var selection: Selection?

    func apply(_ routine: Routine) {
        selection = Selection(
            id: routine.id,
            name: routine.name,
            totalSets: routine.totalSets,
            reps: routine.reps,
            restSeconds: routine.restSeconds
        )
    }

    func clear() {
        selection = nil
    }
}
