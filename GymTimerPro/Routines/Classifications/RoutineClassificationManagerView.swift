//
//  RoutineClassificationManagerView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import SwiftData
import SwiftUI

struct RoutineClassificationManagerView: View {
    enum Mode {
        case manage
        case select
    }

    private let mode: Mode
    @Binding private var selectedClassifications: [RoutineClassification]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\RoutineClassification.name, order: .forward)]) private var classifications: [RoutineClassification]
    @Query(sort: [SortDescriptor(\Routine.name, order: .forward)]) private var routines: [Routine]

    @State private var editorRoute: ClassificationEditorRoute?
    @State private var classificationToDelete: RoutineClassification?
    @State private var showDeleteDialog = false
    @State private var searchText = ""
    @State private var editingClassificationID: UUID?
    @State private var editName: String = ""
    @FocusState private var focusedClassificationID: UUID?
    @State private var isSwitchingEdit = false

    init(
        mode: Mode = .manage,
        selectedClassifications: Binding<[RoutineClassification]> = .constant([])
    ) {
        self.mode = mode
        _selectedClassifications = selectedClassifications
    }

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
                    ClassificationRow(
                        classification: classification,
                        mode: mode,
                        selectedClassifications: $selectedClassifications,
                        editingClassificationID: $editingClassificationID,
                        editName: $editName,
                        focusedClassificationID: $focusedClassificationID,
                        onRequestDelete: { classificationToDelete = $0; showDeleteDialog = true },
                        onBeginEditing: beginEditing,
                        onCancelEditing: cancelInlineEditing
                    )
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
        .onChange(of: focusedClassificationID) { newValue in
            if newValue == nil, editingClassificationID != nil {
                if isSwitchingEdit {
                    isSwitchingEdit = false
                    return
                }
                cancelInlineEditing()
            } else if newValue != nil {
                isSwitchingEdit = false
            }
        }
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

    private func cancelInlineEditing() {
        editingClassificationID = nil
        editName = ""
        focusedClassificationID = nil
        isSwitchingEdit = false
    }

    private func beginEditing(_ classification: RoutineClassification) {
        if let editingClassificationID, editingClassificationID != classification.id {
            isSwitchingEdit = true
        }
        editingClassificationID = classification.id
        editName = classification.name
        DispatchQueue.main.async {
            focusedClassificationID = classification.id
        }
    }

}

private struct ClassificationRow: View {
    @Environment(\.modelContext) private var modelContext
    let classification: RoutineClassification
    let mode: RoutineClassificationManagerView.Mode
    @Binding var selectedClassifications: [RoutineClassification]
    @Binding var editingClassificationID: UUID?
    @Binding var editName: String
    var focusedClassificationID: FocusState<UUID?>.Binding
    let onRequestDelete: (RoutineClassification) -> Void
    let onBeginEditing: (RoutineClassification) -> Void
    let onCancelEditing: () -> Void

    private var isEditing: Bool {
        editingClassificationID == classification.id
    }

    private var isSelected: Bool {
        selectedClassifications.contains { $0.id == classification.id }
    }

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                TextField("classifications.name.placeholder", text: $editName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused(focusedClassificationID, equals: classification.id)
                    .submitLabel(.done)
                    .onSubmit { rename(to: editName) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(classification.name)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            switch mode {
            case .select:
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.iconTint)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
            case .manage:
                if isEditing {
                    Button("common.cancel") {
                        onCancelEditing()
                    }
                    .buttonStyle(.borderless)
                    Button("common.ok") {
                        rename(to: editName)
                    }
                    .buttonStyle(.borderless)
                    .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Menu {
                        Button("classifications.rename.action") {
                            onBeginEditing(classification)
                        }
                        Button("classifications.delete.title", role: .destructive) {
                            onRequestDelete(classification)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                            .padding(.vertical, 6)
                    }
                    .accessibilityLabel(Text(L10n.format("classifications.more_options_format", classification.name)))
                    .disabled(isEditing)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch mode {
            case .select:
                toggleSelection()
            case .manage:
                if !isEditing, editingClassificationID != nil {
                    onCancelEditing()
                }
            }
        }
    }

    private func rename(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        classification.name = trimmed
        onCancelEditing()
        try? modelContext.save()
    }

    private func toggleSelection() {
        if let index = selectedClassifications.firstIndex(where: { $0.id == classification.id }) {
            selectedClassifications.remove(at: index)
        } else {
            selectedClassifications.append(classification)
        }
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
