//
//  RoutineClassificationManagerView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import SwiftData
import SwiftUI

struct RoutineClassificationManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\RoutineClassification.name, order: .forward)]) private var classifications: [RoutineClassification]
    @Query(sort: [SortDescriptor(\Routine.name, order: .forward)]) private var routines: [Routine]

    @State private var editorRoute: ClassificationEditorRoute?
    @State private var classificationToDelete: RoutineClassification?
    @State private var showDeleteDialog = false
    @State private var searchText = ""

    var body: some View {
        List {
            if filteredClassifications.isEmpty {
                ContentUnavailableView {
                    Label("classifications.empty.title", systemImage: "tag")
                } description: {
                    Text("classifications.empty.message")
                }
            } else {
                ForEach(filteredClassifications) { classification in
                    HStack(spacing: 12) {
                        Text(classification.name)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Menu {
                            Button("classifications.rename.action") {
                                editorRoute = .rename(classification)
                            }
                            Button("classifications.delete.title", role: .destructive) {
                                classificationToDelete = classification
                                showDeleteDialog = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .imageScale(.large)
                                .padding(.vertical, 6)
                        }
                        .accessibilityLabel(Text(L10n.format("classifications.more_options_format", classification.name)))
                    }
                }
            }
        }
        .navigationTitle("classifications.manage.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorRoute = .create
                } label: {
                    Label("classifications.add.title", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorRoute) { route in
            NavigationStack {
                RoutineClassificationEditorView(route: route)
            }
        }
        .searchable(text: $searchText, prompt: Text("classifications.search.placeholder"))
        .confirmationDialog(Text("classifications.delete.title"), isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("classifications.delete.title", role: .destructive) {
                if let classificationToDelete {
                    delete(classificationToDelete)
                }
                classificationToDelete = nil
            }
            Button("common.cancel", role: .cancel) {
                classificationToDelete = nil
            }
        } message: {
            Text("classifications.delete.message")
        }
    }

    private func delete(_ classification: RoutineClassification) {
        for routine in routines {
            routine.classifications.removeAll { $0.id == classification.id }
        }
        modelContext.delete(classification)
        try? modelContext.save()
    }

    private var filteredClassifications: [RoutineClassification] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return classifications }
        return classifications.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}

enum ClassificationEditorRoute: Identifiable {
    case create
    case rename(RoutineClassification)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .rename(let classification):
            return classification.id.uuidString
        }
    }

    var classification: RoutineClassification? {
        switch self {
        case .create:
            return nil
        case .rename(let classification):
            return classification
        }
    }

    var titleKey: String {
        switch self {
        case .create:
            return "classifications.add.title"
        case .rename:
            return "classifications.rename.title"
        }
    }
}

#Preview {
    NavigationStack {
        RoutineClassificationManagerView()
    }
    .modelContainer(for: [Routine.self, RoutineClassification.self], inMemory: true)
}
