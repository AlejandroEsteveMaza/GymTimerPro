//
//  RoutinesListView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftData
import SwiftUI

struct RoutinesListView: View {
    @EnvironmentObject private var store: RoutinesStore
    @EnvironmentObject private var routineSelectionStore: RoutineSelectionStore
    @State private var editorRoute: RoutineEditorRoute?

    var body: some View {
        Group {
            if store.routines.isEmpty {
                ContentUnavailableView {
                    Label("routines.empty.title", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("routines.empty.message")
                }
                .padding(.top, 32)
            } else {
                List {
                    ForEach(store.routines) { routine in
                        let isApplied = routineSelectionStore.selection?.id == routine.id
                        NavigationLink {
                            RoutineEditorView(routine: routine)
                                .environmentObject(store)
                                .environmentObject(routineSelectionStore)
                        } label: {
                            RoutineRowView(routine: routine)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if isApplied {
                                Button {
                                    routineSelectionStore.clear()
                                } label: {
                                    Label("routines.remove_from_training", systemImage: "xmark.circle")
                                }
                                .tint(.gray)
                            } else {
                                Button {
                                    routineSelectionStore.apply(routine)
                                } label: {
                                    Label("routines.apply", systemImage: "checkmark.circle")
                                }
                                .tint(.blue)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                if isApplied {
                                    routineSelectionStore.clear()
                                }
                                store.delete(routine)
                            } label: {
                                Label("routines.delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("routines.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorRoute = .create
                } label: {
                    Label("routines.add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorRoute) { route in
            NavigationStack {
                RoutineEditorView(routine: route.routine)
            }
            .environmentObject(store)
            .environmentObject(routineSelectionStore)
        }
    }
}

private enum RoutineEditorRoute: Identifiable {
    case create
    case edit(Routine)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let routine):
            return routine.id.uuidString
        }
    }

    var routine: Routine? {
        switch self {
        case .create:
            return nil
        case .edit(let routine):
            return routine
        }
    }
}

private struct RoutineRowView: View {
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
        RoutinesListView()
            .environmentObject(RoutinesStore())
            .environmentObject(RoutineSelectionStore())
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
