//
//  RoutinePickerView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftData
import SwiftUI

struct RoutinePickerView: View {
    let isApplied: Bool
    let onRemove: () -> Void
    let onSelect: (Routine) -> Void

    init(
        isApplied: Bool = false,
        onRemove: @escaping () -> Void = {},
        onSelect: @escaping (Routine) -> Void
    ) {
        self.isApplied = isApplied
        self.onRemove = onRemove
        self.onSelect = onSelect
    }

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
                    unclassifiedPlacement: .bottom,
                    leadingContent: {
                        if isApplied {
                            Section {
                                Button {
                                    onRemove()
                                    dismiss()
                                } label: {
                                    Label("routines.remove_from_training", systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                ) { routine in
                    RoutineRowView(routine: routine)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(routine)
                            dismiss()
                        }
                        .accessibilityAddTraits(.isButton)
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
