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

    @State private var classificationToDelete: RoutineClassification?
    @State private var showDeleteDialog = false
    @State private var searchText = ""
    @State private var isCreating = false
    @State private var createName: String = ""
    @State private var editingClassificationID: UUID?
    @State private var editName: String = ""
    @FocusState private var focusedClassificationID: UUID?
    @FocusState private var isCreateFocused: Bool
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
            if mode == .manage, isCreating {
                createRow
            }

            if filteredClassifications.isEmpty, !isCreating {
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
                        hasInlineEditing: isCreating || editingClassificationID != nil,
                        showRenameDuplicateError: showRenameDuplicateError(for: classification),
                        editingClassificationID: $editingClassificationID,
                        editName: $editName,
                        focusedClassificationID: $focusedClassificationID,
                        onRequestDelete: { classificationToDelete = $0; showDeleteDialog = true },
                        onBeginEditing: beginEditing,
                        canRename: { name in isNameAvailable(name, excluding: classification) },
                        onRename: rename,
                        onCancelEditing: cancelAnyEditing
                    )
                }
            }
        }
        .navigationTitle("classifications.manage.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .manage {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        beginCreate()
                    } label: {
                        Label("classifications.add.title", systemImage: "plus")
                    }
                    .disabled(isCreating)
                }
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
        .onChange(of: isCreateFocused) { newValue in
            if !newValue, isCreating {
                cancelCreate()
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

    private var createRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                TextField("classifications.name.placeholder", text: $createName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isCreateFocused)
                    .submitLabel(.done)
                    .onSubmit { createClassification() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("common.cancel") {
                    cancelCreate()
                }
                .buttonStyle(.borderless)
                Button("common.ok") {
                    createClassification()
                }
                .buttonStyle(.borderless)
                .disabled(!canCreate)
            }
            if showCreateDuplicateError {
                Text("classifications.duplicate")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .systemRed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCreateFocused {
                isCreateFocused = true
            }
        }
    }

    private var canCreate: Bool {
        let trimmed = createName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && isNameAvailable(trimmed, excluding: nil)
    }

    private var showCreateDuplicateError: Bool {
        let trimmed = createName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !isNameAvailable(trimmed, excluding: nil)
    }

    private func cancelInlineEditing() {
        editingClassificationID = nil
        editName = ""
        focusedClassificationID = nil
        isSwitchingEdit = false
    }

    private func cancelCreate() {
        isCreating = false
        createName = ""
        isCreateFocused = false
    }

    private func cancelAnyEditing() {
        cancelInlineEditing()
        cancelCreate()
    }

    private func beginCreate() {
        cancelInlineEditing()
        isCreating = true
        createName = ""
        DispatchQueue.main.async {
            isCreateFocused = true
        }
    }

    private func beginEditing(_ classification: RoutineClassification) {
        if let editingClassificationID, editingClassificationID != classification.id {
            isSwitchingEdit = true
        }
        cancelCreate()
        editingClassificationID = classification.id
        editName = classification.name
        DispatchQueue.main.async {
            focusedClassificationID = classification.id
        }
    }

    private func createClassification() {
        let trimmed = createName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isNameAvailable(trimmed, excluding: nil) else { return }
        let classification = RoutineClassification(name: trimmed)
        modelContext.insert(classification)
        try? modelContext.save()
        cancelCreate()
    }

    private func rename(_ classification: RoutineClassification, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isNameAvailable(trimmed, excluding: classification) else { return }
        let normalized = RoutineClassification.normalize(trimmed)
        classification.name = trimmed
        classification.normalizedName = normalized
        cancelInlineEditing()
        try? modelContext.save()
    }

    private func showRenameDuplicateError(for classification: RoutineClassification) -> Bool {
        guard editingClassificationID == classification.id else { return false }
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !isNameAvailable(trimmed, excluding: classification)
    }

    private func isNameAvailable(_ name: String, excluding: RoutineClassification?) -> Bool {
        let normalized = RoutineClassification.normalize(name)
        guard !normalized.isEmpty else { return false }
        return !classifications.contains { candidate in
            if let excluding, candidate.id == excluding.id {
                return false
            }
            return candidate.normalizedName == normalized
        }
    }

}

private struct ClassificationRow: View {
    let classification: RoutineClassification
    let mode: RoutineClassificationManagerView.Mode
    @Binding var selectedClassifications: [RoutineClassification]
    let hasInlineEditing: Bool
    let showRenameDuplicateError: Bool
    @Binding var editingClassificationID: UUID?
    @Binding var editName: String
    var focusedClassificationID: FocusState<UUID?>.Binding
    let onRequestDelete: (RoutineClassification) -> Void
    let onBeginEditing: (RoutineClassification) -> Void
    let canRename: (String) -> Bool
    let onRename: (RoutineClassification, String) -> Void
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
                    .onSubmit { onRename(classification, editName) }
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
                        onRename(classification, editName)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canRename(editName))
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
                if !isEditing, hasInlineEditing {
                    onCancelEditing()
                }
            }
        }
        if showRenameDuplicateError, isEditing {
            Text("classifications.duplicate")
                .font(.caption)
                .foregroundStyle(Color(uiColor: .systemRed))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
