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
    @Query(sort: [SortDescriptor(\RoutineClassification.name, order: .forward)]) private var classifications: [RoutineClassification]
    @State private var editorRoute: RoutineEditorRoute?
    @State private var isShowingClassificationManager = false

    var body: some View {
        Group {
            if store.routines.isEmpty && classifications.isEmpty {
                ContentUnavailableView {
                    Label("routines.empty.title", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("routines.empty.message")
                }
                .padding(.top, 32)
            } else {
                RoutineCatalogListView(
                    routines: store.routines,
                    classifications: classifications,
                    unclassifiedPlacement: .bottom
                ) { routine in
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
            }
        }
        .navigationTitle("routines.title")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("classifications.manage.title") {
                        isShowingClassificationManager = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }

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
        .sheet(isPresented: $isShowingClassificationManager) {
            NavigationStack {
                RoutineClassificationManagerView()
            }
        }
    }
}

private enum RoutineEditorRoute: Identifiable {
    case create

    var id: String {
        switch self {
        case .create:
            return "create"
        }
    }

    var routine: Routine? {
        switch self {
        case .create:
            return nil
        }
    }
}

#Preview {
    NavigationStack {
        RoutinesListView()
            .environmentObject(RoutinesStore())
            .environmentObject(RoutineSelectionStore())
    }
    .modelContainer(for: [Routine.self, RoutineClassification.self], inMemory: true)
}
