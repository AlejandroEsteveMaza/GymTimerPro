//
//  RoutineCatalogListView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

struct RoutineCatalogListView<LeadingContent: View, RowContent: View>: View {
    enum UnclassifiedPlacement {
        case top
        case bottom
    }

    let routines: [Routine]
    let classifications: [RoutineClassification]
    let searchPromptKey: String
    let unclassifiedPlacement: UnclassifiedPlacement
    let leadingContent: LeadingContent
    let rowContent: (Routine) -> RowContent

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var expandedClassificationIDs: Set<UUID> = []
    @State private var viewModel = RoutineCatalogViewModel()

    init(
        routines: [Routine],
        classifications: [RoutineClassification],
        searchPromptKey: String = "classifications.search.prompt",
        unclassifiedPlacement: UnclassifiedPlacement = .top,
        @ViewBuilder leadingContent: () -> LeadingContent = { EmptyView() },
        @ViewBuilder rowContent: @escaping (Routine) -> RowContent
    ) {
        self.routines = routines
        self.classifications = classifications
        self.searchPromptKey = searchPromptKey
        self.unclassifiedPlacement = unclassifiedPlacement
        self.leadingContent = leadingContent()
        self.rowContent = rowContent
    }

    var body: some View {
        List {
            leadingContent

            if viewModel.data.isSearching {
                if !viewModel.data.matchingClassifications.isEmpty {
                    Section(header: Text("classifications.section.list")) {
                        ForEach(viewModel.data.matchingClassifications) { classification in
                            let isExpanded = expandedClassificationIDs.contains(classification.id)
                            DisclosureGroup(isExpanded: bindingForExpanded(classification.id)) {
                                if isExpanded {
                                    let routines = viewModel.data.routinesForClassification(classification)
                                    ForEach(routines) { routine in
                                        rowContent(routine)
                                    }
                                }
                            } label: {
                                Text(classification.name)
                            }
                        }
                    }
                }

                if !viewModel.data.matchingRoutines.isEmpty {
                    Section(header: Text("classifications.routines.section")) {
                        ForEach(viewModel.data.matchingRoutines) { routine in
                            rowContent(routine)
                        }
                    }
                }
            } else {
                let showUnclassifiedFirst = unclassifiedPlacement == .top || viewModel.data.sortedClassifications.isEmpty

                if showUnclassifiedFirst, !viewModel.data.unclassifiedRoutines.isEmpty {
                    Section(header: Text("classifications.unclassified.section")) {
                        ForEach(viewModel.data.unclassifiedRoutines) { routine in
                            rowContent(routine)
                        }
                    }
                }

                if !viewModel.data.sortedClassifications.isEmpty {
                    Section(header: Text("classifications.section.list")) {
                        ForEach(viewModel.data.sortedClassifications) { classification in
                            let isExpanded = expandedClassificationIDs.contains(classification.id)
                            DisclosureGroup(isExpanded: bindingForExpanded(classification.id)) {
                                if isExpanded {
                                    let routines = viewModel.data.routinesForClassification(classification)
                                    ForEach(routines) { routine in
                                        rowContent(routine)
                                    }
                                }
                            } label: {
                                Text(classification.name)
                            }
                        }
                    }
                }

                if !showUnclassifiedFirst, !viewModel.data.unclassifiedRoutines.isEmpty {
                    Section(header: Text("classifications.unclassified.section")) {
                        ForEach(viewModel.data.unclassifiedRoutines) { routine in
                            rowContent(routine)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .searchable(text: $searchText, prompt: Text(LocalizedStringKey(searchPromptKey)))
        .onChange(of: searchText) { _, _ in rebuildData() }
        .onChange(of: routines) { _, _ in rebuildData() }
        .onChange(of: classifications) { _, _ in rebuildData() }
        .onAppear { rebuildData() }
    }

    private func bindingForExpanded(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedClassificationIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    if viewModel.data.isSearching {
                        expandedClassificationIDs.insert(id)
                    } else {
                        expandedClassificationIDs = [id]
                    }
                } else {
                    expandedClassificationIDs.remove(id)
                }
            }
        )
    }

    private func rebuildData() {
        viewModel.update(
            routines: routines,
            classifications: classifications,
            searchText: searchText,
            modelContext: modelContext
        )
        updateExpandedForSearch()
    }

    private func updateExpandedForSearch() {
        if viewModel.data.isSearching {
            expandedClassificationIDs = viewModel.data.matchingClassificationIDs
        } else {
            expandedClassificationIDs.removeAll()
        }
    }
}

@MainActor
@Observable
private final class RoutineCatalogViewModel {
    private(set) var data = RoutineCatalogData.empty

    func update(
        routines: [Routine],
        classifications: [RoutineClassification],
        searchText: String,
        modelContext: ModelContext?
    ) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var matchingRoutines: [Routine] = []
        var matchingClassifications: [RoutineClassification] = []

        if let modelContext, !trimmed.isEmpty {
            let routineDescriptor = FetchDescriptor<Routine>(
                predicate: #Predicate { $0.name.localizedStandardContains(trimmed) },
                sortBy: [SortDescriptor(\Routine.name, order: .forward)]
            )
            let classificationDescriptor = FetchDescriptor<RoutineClassification>(
                predicate: #Predicate { $0.name.localizedStandardContains(trimmed) },
                sortBy: [SortDescriptor(\RoutineClassification.name, order: .forward)]
            )
            matchingRoutines = (try? modelContext.fetch(routineDescriptor)) ?? []
            matchingClassifications = (try? modelContext.fetch(classificationDescriptor)) ?? []
        }

        data = RoutineCatalogData(
            routines: routines,
            classifications: classifications,
            matchingClassifications: matchingClassifications,
            matchingRoutines: matchingRoutines,
            searchText: trimmed
        )
    }
}

private struct RoutineCatalogData {
    static let empty = RoutineCatalogData(
        routines: [],
        classifications: [],
        matchingClassifications: [],
        matchingRoutines: [],
        searchText: ""
    )
    let sortedRoutines: [Routine]
    let sortedClassifications: [RoutineClassification]
    let unclassifiedRoutines: [Routine]
    let matchingClassifications: [RoutineClassification]
    let matchingRoutines: [Routine]
    let isSearching: Bool
    let matchingClassificationIDs: Set<UUID>

    private let routinesByClassificationID: [UUID: [Routine]]
    private let searchText: String

    init(
        routines: [Routine],
        classifications: [RoutineClassification],
        matchingClassifications: [RoutineClassification],
        matchingRoutines: [Routine],
        searchText: String
    ) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.searchText = trimmed
        self.isSearching = !trimmed.isEmpty

        self.sortedRoutines = routines
        var map: [UUID: [Routine]] = [:]
        for routine in sortedRoutines {
            for classification in routine.classifications {
                map[classification.id, default: []].append(routine)
            }
        }
        self.routinesByClassificationID = map

        self.sortedClassifications = classifications.filter { map[$0.id] != nil }

        self.unclassifiedRoutines = sortedRoutines.filter { $0.classifications.isEmpty }

        if trimmed.isEmpty {
            self.matchingClassifications = []
            self.matchingRoutines = []
            self.matchingClassificationIDs = []
        } else {
            let matchedClassifications = matchingClassifications.filter { map[$0.id] != nil }
            self.matchingClassifications = matchedClassifications
            self.matchingClassificationIDs = Set(matchedClassifications.map(\.id))

            var shownIDs = Set<UUID>()
            for classification in matchedClassifications {
                let routines = map[classification.id] ?? []
                routines.forEach { shownIDs.insert($0.id) }
            }
            self.matchingRoutines = matchingRoutines.filter { !shownIDs.contains($0.id) }
        }
    }

    func routinesForClassification(_ classification: RoutineClassification) -> [Routine] {
        let routines = routinesByClassificationID[classification.id] ?? []
        guard isSearching else { return routines }
        guard !searchText.isEmpty else { return routines }
        if matchingClassificationIDs.contains(classification.id) {
            return routines
        }
        return routines.filter { $0.name.localizedStandardContains(searchText) }
    }
}
