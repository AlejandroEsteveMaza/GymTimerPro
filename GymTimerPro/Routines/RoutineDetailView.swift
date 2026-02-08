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
    @State private var isEditing = false

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

            Section {
                Button {
                    if isApplied {
                        routineSelectionStore.clear()
                    } else {
                        routineSelectionStore.apply(routine)
                    }
                } label: {
                    Label(
                        isApplied ? "routines.remove_from_training" : "routines.apply",
                        systemImage: isApplied ? "xmark.circle" : "checkmark.circle"
                    )
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("routines.edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                RoutineEditorView(routine: routine)
            }
            .environmentObject(store)
            .environmentObject(routineSelectionStore)
        }
    }

    private var isApplied: Bool {
        routineSelectionStore.selection?.id == routine.id
    }
}
