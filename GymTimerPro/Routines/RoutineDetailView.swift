//
//  RoutineDetailView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftData
import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine
    @EnvironmentObject private var store: RoutinesStore
    @EnvironmentObject private var routineSelectionStore: RoutineSelectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showDeleteAlert = false

    var body: some View {
        Form {
            Section(header: Text("routines.section.details")) {
                LabeledContent(LocalizedStringKey("routines.field.name"), value: routine.name)
            }

            Section(header: Text("routines.section.parameters")) {
                LabeledContent(LocalizedStringKey("config.total_sets.title")) {
                    Text("\(routine.totalSets)")
                }
                LabeledContent(LocalizedStringKey("routines.field.reps")) {
                    Text("\(routine.reps)")
                }
                LabeledContent(LocalizedStringKey("config.rest_seconds.title")) {
                    Text("\(routine.restSeconds)")
                }
                LabeledContent(LocalizedStringKey("routines.field.weight")) {
                    Text(RoutineFormatting.weightValueText(routine.weightKg))
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if isApplied {
                        routineSelectionStore.clear()
                    } else {
                        routineSelectionStore.apply(routine)
                    }
                } label: {
                    Image(systemName: isApplied ? "xmark.circle" : "checkmark.circle")
                }
                .accessibilityLabel(Text(isApplied ? "routines.remove_from_training" : "routines.apply"))

                Button("routines.edit") {
                    isEditing = true
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(Text("routines.delete"))
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                RoutineEditorView(routine: routine)
            }
            .environmentObject(store)
        }
        .alert(Text("routines.delete"), isPresented: $showDeleteAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("routines.delete", role: .destructive) {
                if isApplied {
                    routineSelectionStore.clear()
                }
                store.delete(routine)
                dismiss()
            }
        }
    }

    private var isApplied: Bool {
        routineSelectionStore.selection?.id == routine.id
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(
            routine: Routine(name: "Upper Body", totalSets: 4, reps: 10, restSeconds: 90, weightKg: 20)
        )
        .environmentObject(RoutinesStore())
        .environmentObject(RoutineSelectionStore())
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
