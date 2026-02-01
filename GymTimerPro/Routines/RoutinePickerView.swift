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
    @Query(sort: [SortDescriptor(\RoutineClassification.name, order: .forward)]) private var classifications: [RoutineClassification]
    @EnvironmentObject private var routineSelectionStore: RoutineSelectionStore

    var body: some View {
        Group {
            if routines.isEmpty && classifications.isEmpty {
                ContentUnavailableView {
                    Label("routines.empty.title", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("routines.empty.message")
                }
                .padding(.top, 32)
            } else {
                RoutineCatalogListView(
                    routines: routines,
                    classifications: classifications,
                    leadingContent: {
                        if routineSelectionStore.selection != nil {
                            Section {
                                Button {
                                    routineSelectionStore.clear()
                                    dismiss()
                                } label: {
                                    Label("routines.remove_from_training", systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                ) { routine in
                    Button {
                        onSelect(routine)
                        dismiss()
                    } label: {
                        RoutineRowView(routine: routine)
                    }
                    .buttonStyle(.plain)
                }
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

#Preview {
    NavigationStack {
        RoutinePickerView { _ in }
            .environmentObject(RoutineSelectionStore())
    }
    .modelContainer(for: [Routine.self, RoutineClassification.self], inMemory: true)
}
