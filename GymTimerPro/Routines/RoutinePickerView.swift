//
//  RoutinePickerView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftData
import SwiftUI

struct RoutinePickerView: View {
    let onSelect: (Routine) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Routine.name, order: .forward)]) private var routines: [Routine]

    var body: some View {
        Group {
            if routines.isEmpty {
                ContentUnavailableView {
                    Label("routines.empty.title", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("routines.empty.message")
                }
                .padding(.top, 32)
            } else {
                List(routines) { routine in
                    Button {
                        onSelect(routine)
                        dismiss()
                    } label: {
                        RoutinePickerRow(routine: routine)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("routines.select.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") {
                    dismiss()
                }
            }
        }
    }
}

private struct RoutinePickerRow: View {
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
    NavigationStack {
        RoutinePickerView { _ in }
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
