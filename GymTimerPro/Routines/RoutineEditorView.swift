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
    private static let nameMaxLength = 50
    private static let weightMaxValue: Double = 999

    @EnvironmentObject private var store: RoutinesStore
    @EnvironmentObject private var routineSelectionStore: RoutineSelectionStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var draft: RoutineDraft
    @State private var weightText: String
    @State private var showDeleteDialog = false
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
                HStack {
                    TextField("routines.field.name", text: nameBinding)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .accessibilityLabel(Text("routines.field.name"))
                        .onChange(of: draft.name) { _, newValue in
                            let clamped = RoutineEditorView.clampName(newValue)
                            if clamped != newValue {
                                draft.name = clamped
                            }
                        }
                    Text("\(nameCount)/\(Self.nameMaxLength)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = .name
                }
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
                    titleKey: "routines.field.reps",
                    icon: "repeat",
                    value: $draft.reps,
                    range: 1...30,
                    accessibilityValue: L10n.format("accessibility.reps_value_format", draft.reps),
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

                ConfigRow(icon: "scalemass", titleKey: "routines.field.weight") {
                    TextField("routines.weight.placeholder", text: weightBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .focused($focusedField, equals: .weight)
                        .accessibilityLabel(Text("routines.field.weight"))
                        .onChange(of: weightText) { _, newValue in
                            let clamped = RoutineEditorView.clampWeightText(newValue)
                            if clamped != newValue {
                                weightText = clamped
                            }
                        }
                }
                .frame(minHeight: Layout.minTapHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = .weight
                }
            }

            if routine != nil {
                Section {
                    Button {
                        handleApplyAction()
                    } label: {
                        Label(
                            isApplied ? "routines.remove_from_training" : "routines.apply",
                            systemImage: isApplied ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                    .disabled(!isApplied && !canApply)
                }
            }

            if routine != nil {
                Section {
                    Button(role: .destructive) {
                        showDeleteDialog = true
                    } label: {
                        Label("routines.delete", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
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
        .confirmationDialog(Text("routines.delete"), isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("routines.delete", role: .destructive) {
                guard let routine else { return }
                if routineSelectionStore.selection?.id == routine.id {
                    routineSelectionStore.clear()
                }
                store.delete(routine)
                dismiss()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("routines.delete.message")
        }
        .simultaneousGesture(
            // Keep this gesture close to the iOS interactive back gesture: only from the leading edge.
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let isFromLeadingEdge = value.startLocation.x <= 24
                    let isHorizontal = abs(value.translation.height) < 60
                    let isRightSwipe = value.translation.width > 120 || value.predictedEndTranslation.width > 160
                    if isFromLeadingEdge && isHorizontal && isRightSwipe {
                        handleCancel()
                    }
                }
        )
    }

    private var editorTitleKey: String {
        routine == nil ? "routines.create.title" : "routines.edit.title"
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameCount: Int {
        draft.name.count
    }

    private var isNameAtLimit: Bool {
        nameCount >= Self.nameMaxLength
    }

    private var parsedWeight: Double? {
        RoutineFormatting.parseWeight(weightText)
    }

    private var isWeightValid: Bool {
        if weightText.isEmpty {
            return true
        }
        guard let parsedWeight else { return false }
        return parsedWeight >= 0 && parsedWeight <= Self.weightMaxValue
    }

    private var canSave: Bool {
        !trimmedName.isEmpty &&
            nameCount <= Self.nameMaxLength &&
            draft.totalSets > 0 &&
            draft.reps > 0 &&
            draft.restSeconds >= 0 &&
            isWeightValid
    }

    private var canApply: Bool {
        guard routine != nil else { return false }
        return !hasChanges || canSave
    }

    private var isApplied: Bool {
        guard let routine else { return false }
        return routineSelectionStore.selection?.id == routine.id
    }

    private var hasChanges: Bool {
        draft != initialDraft || weightText != initialWeightText
    }

    private func handleCancel() {
        dismiss()
    }

    private func saveRoutine() {
        guard canSave else { return }
        let payload = currentPayload

        if let routine {
            store.update(routine, with: payload)
        } else {
            store.create(from: payload)
        }
        dismiss()
    }

    private func applyRoutineToTraining() {
        guard let routine else { return }
        if hasChanges {
            guard canSave else { return }
            store.update(routine, with: currentPayload)
        }
        routineSelectionStore.apply(routine)
        dismiss()
    }

    private func handleApplyAction() {
        if isApplied {
            routineSelectionStore.clear()
            return
        }
        applyRoutineToTraining()
    }

    private var currentPayload: RoutineDraft {
        RoutineDraft(
            name: trimmedName,
            totalSets: draft.totalSets,
            reps: draft.reps,
            restSeconds: draft.restSeconds,
            weightKg: parsedWeight
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { draft.name },
            set: { draft.name = RoutineEditorView.clampName($0) }
        )
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { weightText },
            set: { weightText = RoutineEditorView.clampWeightText($0) }
        )
    }

    private static func clampName(_ value: String) -> String {
        if value.count <= nameMaxLength {
            return value
        }
        return String(value.prefix(nameMaxLength))
    }

    private static func clampWeightText(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        let formatter = RoutineFormatting.numberFormatter
        let decimalSeparator = formatter.decimalSeparator ?? "."
        let maxFractionDigits = formatter.maximumFractionDigits

        var filtered = ""
        var hasSeparator = false
        for character in value {
            if character.isNumber {
                filtered.append(character)
                continue
            }
            if String(character) == decimalSeparator, !hasSeparator {
                filtered.append(character)
                hasSeparator = true
            }
        }

        if filtered.isEmpty {
            return ""
        }

        if filtered.hasPrefix(decimalSeparator) {
            filtered = "0" + filtered
        }

        let parts = filtered.split(separator: Character(decimalSeparator), omittingEmptySubsequences: false)
        var integerPart = String(parts.first ?? "")
        var fractionPart = parts.count > 1 ? String(parts[1]) : ""

        if integerPart.count > 3 {
            integerPart = String(integerPart.prefix(3))
            fractionPart = ""
        }

        if fractionPart.count > maxFractionDigits {
            fractionPart = String(fractionPart.prefix(maxFractionDigits))
        }

        var sanitized = integerPart
        if hasSeparator, maxFractionDigits > 0 {
            sanitized += decimalSeparator + fractionPart
        }

        if let parsed = RoutineFormatting.parseWeight(sanitized), parsed > weightMaxValue {
            return formatter.string(from: NSNumber(value: weightMaxValue)) ?? "\(weightMaxValue)"
        }
        return sanitized
    }
}

#Preview {
    NavigationStack {
        RoutineEditorView()
            .environmentObject(RoutinesStore())
            .environmentObject(RoutineSelectionStore())
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
