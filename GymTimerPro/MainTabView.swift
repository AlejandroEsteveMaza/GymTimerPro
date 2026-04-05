//
//  MainTabView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var alertReadinessChecker = AlertReadinessChecker()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("tab.training", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                RoutinesRootView()
            }
            .tabItem {
                Label("tab.routines", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                ProgramProgressView()
            }
            .tabItem {
                Label("tab.progress", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                SettingsRootView()
            }
            .tabItem {
                Label("tab.settings", systemImage: "gear")
            }
        }
        .environmentObject(alertReadinessChecker)
        .onAppear {
            alertReadinessChecker.check()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                alertReadinessChecker.check()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(PurchaseManager(startTasks: false))
        .environmentObject(RoutineSelectionStore())
        .modelContainer(for: [Routine.self, RoutineClassification.self, WorkoutCompletion.self], inMemory: true)
}
