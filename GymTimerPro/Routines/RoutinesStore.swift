//
//  RoutinesStore.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import Combine
import Foundation
import SwiftData

struct RoutineDraft: Equatable {
    static let defaultTotalSets = 4
    static let defaultRestSeconds = 90

    var name: String
    var totalSets: Int
    var restSeconds: Int
    var weightKg: Double?

    init(
        name: String = "",
        totalSets: Int = RoutineDraft.defaultTotalSets,
        restSeconds: Int = RoutineDraft.defaultRestSeconds,
        weightKg: Double? = nil
    ) {
        self.name = name
        self.totalSets = totalSets
        self.restSeconds = restSeconds
        self.weightKg = weightKg
    }

    init(routine: Routine?) {
        if let routine {
            self.name = routine.name
            self.totalSets = routine.totalSets
            self.restSeconds = routine.restSeconds
            self.weightKg = routine.weightKg
        } else {
            self.name = ""
            self.totalSets = RoutineDraft.defaultTotalSets
            self.restSeconds = RoutineDraft.defaultRestSeconds
            self.weightKg = nil
        }
    }
}

@MainActor
final class RoutinesStore: ObservableObject {
    @Published private(set) var routines: [Routine] = []

    private var modelContext: ModelContext?
    private var isConfigured = false

    func configure(context: ModelContext) {
        guard !isConfigured else { return }
        modelContext = context
        isConfigured = true
        refresh()
    }

    func refresh() {
        guard let modelContext else {
            routines = []
            return
        }
        let descriptor = FetchDescriptor<Routine>(
            sortBy: [SortDescriptor(\Routine.name, order: .forward)]
        )
        routines = (try? modelContext.fetch(descriptor)) ?? []
    }

    func create(from draft: RoutineDraft) {
        guard let modelContext else { return }
        let routine = Routine(
            name: draft.name,
            totalSets: draft.totalSets,
            restSeconds: draft.restSeconds,
            weightKg: draft.weightKg
        )
        modelContext.insert(routine)
        try? modelContext.save()
        refresh()
    }

    func update(_ routine: Routine, with draft: RoutineDraft) {
        routine.name = draft.name
        routine.totalSets = draft.totalSets
        routine.restSeconds = draft.restSeconds
        routine.weightKg = draft.weightKg
        routine.updatedAt = Date()
        try? modelContext?.save()
        refresh()
    }

    func delete(_ routine: Routine) {
        modelContext?.delete(routine)
        try? modelContext?.save()
        refresh()
    }

    func delete(at offsets: IndexSet) {
        offsets.map { routines[$0] }.forEach(delete)
    }
}
