//
//  RoutinesRootView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftUI
import SwiftData

struct RoutinesRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = RoutinesStore()

    var body: some View {
        RoutinesListView()
            .environmentObject(store)
            .task {
                store.configure(context: modelContext)
            }
    }
}

#Preview {
    RoutinesRootView()
        .modelContainer(for: Routine.self, inMemory: true)
        .environmentObject(RoutineSelectionStore())
}
