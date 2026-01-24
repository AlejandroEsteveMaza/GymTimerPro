//
//  RoutineEditorView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftData
import SwiftUI

struct RoutineEditorView: View {
    private enum Field {
        case name
        case weight
    }

    let routine: Routine?
    private let initialDraft: RoutineDraft
    private let initialWeightText: String

    @EnvironmentObject private var store: RoutinesStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var draft: RoutineDraft
    @State private var weightText: String
    @State private var showDiscardAlert = false
    @State private var stepperControlSize: CGSize = Layout.defaultStepperControlSize

    init(routine: Routine? = nil) {
        self.routine = routine
        let draft = RoutineDraft(routine: routine)
        self.initialDraft = draft
        let weightText = RoutineFormatting.weightInputText(draft.weightKg)
        self.initialWeightText = weightText
        _draft = State(initialValue: draft)
        _weightText = State(initialValue: weightText)
    }

    var body: some View {
        Form {
            Section(header: Text("routines.section.details")) {
                TextField("routines.field.name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
                    .accessibilityLabel(Text("routines.field.name"))
            }

            Section(header: Text("routines.section.parameters")) {
                NumericConfigRow(
                    titleKey: "config.total_sets.title",
                    icon: "square.stack.3d.up",
                    value: $draft.totalSets,
                    range: 1...10,
                    accessibilityValue: L10n.format("accessibility.total_sets_value_format", draft.totalSets),
                    stepperControlSize: $stepperControlSize
                )

                NumericConfigRow(
                    titleKey: "config.rest_seconds.title",
                    icon: "timer",
                    value: $draft.restSeconds,
                    range: 15...300,
                    step: 15,
                    accessibilityValue: L10n.format("accessibility.rest_seconds_value_format", draft.restSeconds),
                    stepperControlSize: $stepperControlSize
                )

                TextField("routines.field.weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .accessibilityLabel(Text("routines.field.weight"))
            }
        }
        .navigationTitle(LocalizedStringKey(editorTitleKey))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") {
                    handleCancel()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("routines.save") {
                    saveRoutine()
                }
                .disabled(!canSave)
            }
        }
        .overlay(alignment: .topTrailing) {
            StepperSizeReader(size: $stepperControlSize)
        }
        .interactiveDismissDisabled(hasChanges)
        .alert(Text("routines.discard.title"), isPresented: $showDiscardAlert) {
            Button("routines.discard.keep_editing", role: .cancel) {}
            Button("routines.discard.confirm", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("routines.discard.message")
        }
    }

    private var editorTitleKey: String {
        routine == nil ? "routines.create.title" : "routines.edit.title"
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedWeight: Double? {
        RoutineFormatting.parseWeight(weightText)
    }

    private var isWeightValid: Bool {
        if weightText.isEmpty {
            return true
        }
        guard let parsedWeight else { return false }
        return parsedWeight >= 0
    }

    private var canSave: Bool {
        !trimmedName.isEmpty &&
            draft.totalSets > 0 &&
            draft.restSeconds >= 0 &&
            isWeightValid
    }

    private var hasChanges: Bool {
        draft != initialDraft || weightText != initialWeightText
    }

    private func handleCancel() {
        if hasChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func saveRoutine() {
        guard canSave else { return }
        let payload = RoutineDraft(
            name: trimmedName,
            totalSets: draft.totalSets,
            restSeconds: draft.restSeconds,
            weightKg: parsedWeight
        )

        if let routine {
            store.update(routine, with: payload)
        } else {
            store.create(from: payload)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RoutineEditorView()
            .environmentObject(RoutinesStore())
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
