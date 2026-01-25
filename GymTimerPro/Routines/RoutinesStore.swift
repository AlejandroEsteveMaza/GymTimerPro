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
    static let defaultReps = 10
    static let defaultRestSeconds = 90

    var name: String
    var totalSets: Int
    var reps: Int
    var restSeconds: Int
    var weightKg: Double?

    init(
        name: String = "",
        totalSets: Int = RoutineDraft.defaultTotalSets,
        reps: Int = RoutineDraft.defaultReps,
        restSeconds: Int = RoutineDraft.defaultRestSeconds,
        weightKg: Double? = nil
    ) {
        self.name = name
        self.totalSets = totalSets
        self.reps = reps
        self.restSeconds = restSeconds
        self.weightKg = weightKg
    }

    init(routine: Routine?) {
        if let routine {
            self.name = routine.name
            self.totalSets = routine.totalSets
            self.reps = routine.reps
            self.restSeconds = routine.restSeconds
            self.weightKg = routine.weightKg
        } else {
            self.name = ""
            self.totalSets = RoutineDraft.defaultTotalSets
            self.reps = RoutineDraft.defaultReps
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

        #if DEBUG
        if shouldSeedRoutines, routines.isEmpty {
            seedSampleRoutines()
        }
        #endif
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
            reps: draft.reps,
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
        routine.reps = draft.reps
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

    #if DEBUG
    private var shouldSeedRoutines: Bool {
        let args = ProcessInfo.processInfo.arguments.map { $0.lowercased() }
        if args.contains("ui-testing-seed-routines") {
            return true
        }
        if let env = ProcessInfo.processInfo.environment["UI_TESTING_SEED_ROUTINES"]?.lowercased() {
            return env == "1" || env == "true" || env == "yes"
        }
        return false
    }

    private func seedSampleRoutines() {
        guard let modelContext else { return }
        let samples: [Routine] = [
            Routine(name: "Fuerza - Basico", totalSets: 5, reps: 5, restSeconds: 120, weightKg: 60),
            Routine(name: "Hipertrofia", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 22.5),
            Routine(name: "Calistenia", totalSets: 6, reps: 12, restSeconds: 60, weightKg: nil),
            Routine(name: "Pierna - Fuerza", totalSets: 5, reps: 5, restSeconds: 150, weightKg: 80),
            Routine(name: "Torso - Fuerza", totalSets: 5, reps: 6, restSeconds: 120, weightKg: 70),
            Routine(name: "Full Body", totalSets: 4, reps: 8, restSeconds: 90, weightKg: 35),
            Routine(name: "Empuje (Push)", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 25),
            Routine(name: "Tiron (Pull)", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 25),
            Routine(name: "Core", totalSets: 3, reps: 15, restSeconds: 60, weightKg: nil),
            Routine(name: "HIIT", totalSets: 10, reps: 20, restSeconds: 30, weightKg: nil),
            Routine(name: "Resistencia", totalSets: 8, reps: 15, restSeconds: 45, weightKg: nil),
            Routine(name: "Deload", totalSets: 3, reps: 8, restSeconds: 120, weightKg: 20),
            Routine(name: "Movilidad", totalSets: 4, reps: 12, restSeconds: 30, weightKg: nil),
            Routine(name: "Brazos", totalSets: 4, reps: 12, restSeconds: 75, weightKg: 15)
        ]
        samples.forEach { modelContext.insert($0) }
        try? modelContext.save()
        refresh()
    }
    #endif
}
