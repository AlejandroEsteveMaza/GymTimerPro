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
    var classifications: [RoutineClassification]

    init(
        name: String = "",
        totalSets: Int = RoutineDraft.defaultTotalSets,
        reps: Int = RoutineDraft.defaultReps,
        restSeconds: Int = RoutineDraft.defaultRestSeconds,
        weightKg: Double? = nil,
        classifications: [RoutineClassification] = []
    ) {
        self.name = name
        self.totalSets = totalSets
        self.reps = reps
        self.restSeconds = restSeconds
        self.weightKg = weightKg
        self.classifications = classifications
    }

    init(routine: Routine?) {
        if let routine {
            self.name = routine.name
            self.totalSets = routine.totalSets
            self.reps = routine.reps
            self.restSeconds = routine.restSeconds
            self.weightKg = routine.weightKg
            self.classifications = routine.classifications
        } else {
            self.name = ""
            self.totalSets = RoutineDraft.defaultTotalSets
            self.reps = RoutineDraft.defaultReps
            self.restSeconds = RoutineDraft.defaultRestSeconds
            self.weightKg = nil
            self.classifications = []
        }
    }

    static func == (lhs: RoutineDraft, rhs: RoutineDraft) -> Bool {
        let lhsIDs = lhs.classifications.map(\.id).sorted()
        let rhsIDs = rhs.classifications.map(\.id).sorted()
        return lhs.name == rhs.name &&
            lhs.totalSets == rhs.totalSets &&
            lhs.reps == rhs.reps &&
            lhs.restSeconds == rhs.restSeconds &&
            lhs.weightKg == rhs.weightKg &&
            lhsIDs == rhsIDs
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

    private func fetchClassifications() -> [RoutineClassification] {
        guard let modelContext else { return [] }
        return (try? modelContext.fetch(FetchDescriptor<RoutineClassification>())) ?? []
    }

    func create(from draft: RoutineDraft) {
        guard let modelContext else { return }
        let routine = Routine(
            name: draft.name,
            totalSets: draft.totalSets,
            reps: draft.reps,
            restSeconds: draft.restSeconds,
            weightKg: clampedWeight(draft.weightKg),
            classifications: draft.classifications
        )
        syncClassifications(for: routine, previous: [], current: draft.classifications)
        modelContext.insert(routine)
        try? modelContext.save()
        refresh()
    }

    func update(_ routine: Routine, with draft: RoutineDraft) {
        let previousClassifications = routine.classifications
        routine.name = draft.name
        routine.totalSets = draft.totalSets
        routine.reps = draft.reps
        routine.restSeconds = draft.restSeconds
        routine.weightKg = clampedWeight(draft.weightKg)
        routine.classifications = draft.classifications
        syncClassifications(for: routine, previous: previousClassifications, current: draft.classifications)
        routine.updatedAt = Date()
        try? modelContext?.save()
        refresh()
    }

    func delete(_ routine: Routine) {
        syncClassifications(for: routine, previous: routine.classifications, current: [])
        routine.classifications.removeAll()
        modelContext?.delete(routine)
        try? modelContext?.save()
        refresh()
    }

    func delete(at offsets: IndexSet) {
        offsets.map { routines[$0] }.forEach(delete)
    }

    private func clampedWeight(_ weight: Double?) -> Double? {
        guard let weight else { return nil }
        return min(max(weight, 0), 999)
    }

    private func syncClassifications(
        for routine: Routine,
        previous: [RoutineClassification],
        current: [RoutineClassification]
    ) {
        let currentIDs = Set(current.map(\.id))

        for classification in current where !classification.routines.contains(where: { $0.id == routine.id }) {
            classification.routines.append(routine)
        }

        for classification in previous where !currentIDs.contains(classification.id) {
            classification.routines.removeAll { $0.id == routine.id }
        }
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

        // Clasificaciones para el seed UI.
        let classificationNames = ["Fuerza", "Hipertrofia", "Resistencia", "Movilidad"]
        var classifications: [String: RoutineClassification] = [:]

        // Cargar todas las clasificaciones una vez y reusar si ya existen.
        let existingClassifications = fetchClassifications()
        for name in classificationNames {
            let normalized = RoutineClassification.normalize(name)
            if let existing = existingClassifications.first(where: { $0.normalizedName == normalized }) {
                classifications[name] = existing
                continue
            }
            let created = RoutineClassification(name: name)
            modelContext.insert(created)
            classifications[name] = created
        }

        let samples: [Routine] = [
            Routine(name: "Fuerza - Basico", totalSets: 5, reps: 5, restSeconds: 120, weightKg: 60, classifications: [classifications["Fuerza"]!]),
            Routine(name: "Hipertrofia", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 22.5, classifications: [classifications["Hipertrofia"]!]),
            Routine(name: "Calistenia", totalSets: 6, reps: 12, restSeconds: 60, weightKg: nil), // sin clasificación
            Routine(name: "Pierna - Fuerza", totalSets: 5, reps: 5, restSeconds: 150, weightKg: 80, classifications: [classifications["Fuerza"]!]),
            Routine(name: "Torso - Fuerza", totalSets: 5, reps: 6, restSeconds: 120, weightKg: 70, classifications: [classifications["Fuerza"]!]),
            Routine(name: "Full Body", totalSets: 4, reps: 8, restSeconds: 90, weightKg: 35), // sin clasificación
            Routine(name: "Empuje (Push)", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 25, classifications: [classifications["Hipertrofia"]!]),
            Routine(name: "Tiron (Pull)", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 25, classifications: [classifications["Hipertrofia"]!]),
            Routine(name: "Core", totalSets: 3, reps: 15, restSeconds: 60, weightKg: nil, classifications: [classifications["Movilidad"]!]),
            Routine(name: "HIIT", totalSets: 10, reps: 20, restSeconds: 30, weightKg: nil, classifications: [classifications["Resistencia"]!]),
            Routine(name: "Resistencia", totalSets: 8, reps: 15, restSeconds: 45, weightKg: nil, classifications: [classifications["Resistencia"]!]),
            Routine(name: "Deload", totalSets: 3, reps: 8, restSeconds: 120, weightKg: 20, classifications: [classifications["Fuerza"]!]),
            Routine(name: "Movilidad", totalSets: 4, reps: 12, restSeconds: 30, weightKg: nil, classifications: [classifications["Movilidad"]!]),
            Routine(name: "Brazos", totalSets: 4, reps: 12, restSeconds: 75, weightKg: 15, classifications: [classifications["Hipertrofia"]!])
        ]

        samples.forEach { modelContext.insert($0) }
        try? modelContext.save()
        refresh()
    }
    #endif
}
