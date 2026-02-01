//
//  RoutineRowView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import SwiftData
import SwiftUI

struct RoutineRowView: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(RoutineFormatting.summaryText(
                sets: routine.totalSets,
                reps: routine.reps,
                restSeconds: routine.restSeconds,
                weightKg: routine.weightKg
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RoutineRowView(
        routine: Routine(name: "Upper Body", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 20)
    )
    .padding()
    .modelContainer(for: [Routine.self, RoutineClassification.self], inMemory: true)
}
