//
//  GymTimerProApp.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 24/12/25.
//

import SwiftData
import SwiftUI

@main
struct GymTimerProApp: App {
    @StateObject private var purchaseManager = PurchaseManager()
    @StateObject private var routineSelectionStore = RoutineSelectionStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(purchaseManager)
                .environmentObject(routineSelectionStore)
        }
        .modelContainer(for: [Routine.self, RoutineClassification.self])
    }
}
