//
//  RoutineCatalogListView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import Foundation
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

    @State private var searchText = ""
    @State private var expandedClassificationIDs: Set<UUID> = []

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
        let data = RoutineCatalogData(routines: routines, classifications: classifications, searchText: searchText)

        List {
            leadingContent

            if data.isSearching {
                if !data.matchingClassifications.isEmpty {
                    Section(header: Text("classifications.section.list")) {
                        ForEach(data.matchingClassifications) { classification in
                            DisclosureGroup(isExpanded: bindingForExpanded(classification.id)) {
                                let routines = data.routinesForClassification(classification)
                                ForEach(routines) { routine in
                                    rowContent(routine)
                                }
                            } label: {
                                Text(classification.name)
                            }
                        }
                    }
                }

                if !data.matchingRoutines.isEmpty {
                    Section(header: Text("classifications.routines.section")) {
                        ForEach(data.matchingRoutines) { routine in
                            rowContent(routine)
                        }
                    }
                }
            } else {
                let showUnclassifiedFirst = unclassifiedPlacement == .top || data.sortedClassifications.isEmpty

                if showUnclassifiedFirst, !data.unclassifiedRoutines.isEmpty {
                    Section(header: Text("classifications.unclassified.section")) {
                        ForEach(data.unclassifiedRoutines) { routine in
                            rowContent(routine)
                        }
                    }
                }

                if !data.sortedClassifications.isEmpty {
                    Section(header: Text("classifications.section.list")) {
                        ForEach(data.sortedClassifications) { classification in
                            DisclosureGroup(isExpanded: bindingForExpanded(classification.id)) {
                                let routines = data.routinesForClassification(classification)
                                ForEach(routines) { routine in
                                    rowContent(routine)
                                }
                            } label: {
                                Text(classification.name)
                            }
                        }
                    }
                }

                if !showUnclassifiedFirst, !data.unclassifiedRoutines.isEmpty {
                    Section(header: Text("classifications.unclassified.section")) {
                        ForEach(data.unclassifiedRoutines) { routine in
                            rowContent(routine)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .searchable(text: $searchText, prompt: Text(LocalizedStringKey(searchPromptKey)))
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                expandedClassificationIDs.removeAll()
            } else {
                let matches = matchingClassificationIDs(for: trimmed)
                expandedClassificationIDs = matches
            }
        }
    }

    private func bindingForExpanded(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedClassificationIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedClassificationIDs.insert(id)
                } else {
                    expandedClassificationIDs.remove(id)
                }
            }
        )
    }

    private func matchingClassificationIDs(for search: String) -> Set<UUID> {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return Set(
            classifications
                .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
                .map(\.id)
        )
    }
}

private struct RoutineCatalogData {
    let sortedRoutines: [Routine]
    let sortedClassifications: [RoutineClassification]
    let unclassifiedRoutines: [Routine]
    let matchingClassifications: [RoutineClassification]
    let matchingRoutines: [Routine]
    let isSearching: Bool
    private let matchingClassificationIDs: Set<UUID>

    private let routinesByClassificationID: [UUID: [Routine]]
    private let searchText: String

    init(routines: [Routine], classifications: [RoutineClassification], searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.searchText = trimmed
        self.isSearching = !trimmed.isEmpty

        self.sortedRoutines = routines.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        var map: [UUID: [Routine]] = [:]
        for routine in sortedRoutines {
            for classification in routine.classifications {
                map[classification.id, default: []].append(routine)
            }
        }
        for (id, list) in map {
            map[id] = list.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
        self.routinesByClassificationID = map

        self.sortedClassifications = classifications
            .filter { map[$0.id] != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        self.unclassifiedRoutines = sortedRoutines.filter { $0.classifications.isEmpty }

        if trimmed.isEmpty {
            self.matchingClassifications = []
            self.matchingRoutines = []
            self.matchingClassificationIDs = []
        } else {
            let matchedClassifications = sortedClassifications.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
            }
            self.matchingClassifications = matchedClassifications
            self.matchingClassificationIDs = Set(matchedClassifications.map(\.id))

            let routineMatches = sortedRoutines.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
            }

            var shownIDs = Set<UUID>()
            for classification in matchedClassifications {
                let routines = map[classification.id] ?? []
                routines.forEach { shownIDs.insert($0.id) }
            }
            self.matchingRoutines = routineMatches.filter { !shownIDs.contains($0.id) }
        }
    }

    func routinesForClassification(_ classification: RoutineClassification) -> [Routine] {
        let routines = routinesByClassificationID[classification.id] ?? []
        guard isSearching else { return routines }
        guard !searchText.isEmpty else { return routines }
        if matchingClassificationIDs.contains(classification.id) {
            return routines
        }
        return routines.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}
