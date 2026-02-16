//
//  RoutineClassificationPickerView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import SwiftData
import SwiftUI

struct RoutineClassificationPickerView: View {
    @Binding var selectedClassifications: [RoutineClassification]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\RoutineClassification.name, order: .forward)]) private var classifications: [RoutineClassification]

    @State private var searchText = ""
    @State private var showDuplicateError = false

    var body: some View {
        List {
            if classifications.isEmpty {
                ContentUnavailableView {
                    Label("classifications.empty.title", systemImage: "tag")
                } description: {
                    Text("classifications.empty.message")
                }
            } else {
                ForEach(filteredClassifications) { classification in
                    Button {
                        toggle(classification)
                    } label: {
                        HStack {
                            Text(classification.name)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if isSelected(classification) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.iconTint)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("classifications.section.title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText) { _, _ in
            if showDuplicateError {
                showDuplicateError = false
            }
        }
        .safeAreaInset(edge: .bottom) {
            classificationInputBar
        }
    }

    private var filteredClassifications: [RoutineClassification] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return classifications }
        return classifications.filter { $0.name.localizedStandardContains(trimmed) }
    }

    private var classificationInputBar: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let canCreate = !trimmed.isEmpty && isNameAvailable(trimmed)

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                TextField("classifications.search.create_placeholder", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                if canCreate {
                    Button {
                        createClassification(named: trimmed)
                    } label: {
                        Label(L10n.format("classifications.create_format", trimmed), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            if showDuplicateError {
                Text("classifications.duplicate")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .systemRed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func toggle(_ classification: RoutineClassification) {
        if let index = selectedClassifications.firstIndex(where: { $0.id == classification.id }) {
            selectedClassifications.remove(at: index)
        } else {
            selectedClassifications.append(classification)
        }
    }

    private func isSelected(_ classification: RoutineClassification) -> Bool {
        selectedClassifications.contains { $0.id == classification.id }
    }
}

#Preview {
    NavigationStack {
        RoutineClassificationPickerView(selectedClassifications: .constant([]))
    }
    .modelContainer(for: [Routine.self, RoutineClassification.self], inMemory: true)
}

private extension RoutineClassificationPickerView {
    func isNameAvailable(_ name: String) -> Bool {
        let normalized = RoutineClassification.normalize(name)
        return !classifications.contains { $0.normalizedName == normalized }
    }

    func createClassification(named name: String) {
        let normalized = RoutineClassification.normalize(name)
        guard !normalized.isEmpty else { return }
        guard isNameAvailable(name) else {
            showDuplicateError = true
            return
        }
        showDuplicateError = false
        let newClassification = RoutineClassification(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(newClassification)
        try? modelContext.save()
        selectedClassifications.append(newClassification)
        searchText = ""
    }
}
