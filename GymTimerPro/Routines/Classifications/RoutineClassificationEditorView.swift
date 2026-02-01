//
//  RoutineClassificationEditorView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import SwiftData
import SwiftUI

struct RoutineClassificationEditorView: View {
    let route: ClassificationEditorRoute
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\RoutineClassification.name, order: .forward)]) private var classifications: [RoutineClassification]

    @State private var name: String

    init(route: ClassificationEditorRoute) {
        self.route = route
        _name = State(initialValue: route.classification?.name ?? "")
    }

    var body: some View {
        Form {
            Section(header: Text("classifications.name.title")) {
                TextField("classifications.name.placeholder", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle(route.titleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("routines.save") {
                    save()
                }
                .disabled(!canSave)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && isNameAvailable(trimmedName)
    }

    private func isNameAvailable(_ name: String) -> Bool {
        let normalized = RoutineClassification.normalize(name)
        return !classifications.contains { candidate in
            if let current = route.classification, candidate.id == current.id {
                return false
            }
            return candidate.normalizedName == normalized
        }
    }

    private func save() {
        let normalized = RoutineClassification.normalize(trimmedName)
        guard !normalized.isEmpty else { return }
        guard isNameAvailable(trimmedName) else { return }
        if let classification = route.classification {
            classification.name = trimmedName
            classification.normalizedName = normalized
        } else {
            let classification = RoutineClassification(name: trimmedName)
            modelContext.insert(classification)
        }
        try? modelContext.save()
        dismiss()
    }
}

