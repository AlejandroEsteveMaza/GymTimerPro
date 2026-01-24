//
//  MainTabView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("tab.training", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                TabPlaceholderView(messageKey: "placeholder.coming_soon")
            }
            .tabItem {
                Label("tab.routines", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                TabPlaceholderView(messageKey: "placeholder.coming_soon")
            }
            .tabItem {
                Label("tab.progress", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                TabPlaceholderView(messageKey: "placeholder.coming_soon")
            }
            .tabItem {
                Label("tab.settings", systemImage: "gear")
            }
        }
    }
}

private struct TabPlaceholderView: View {
    let messageKey: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            Text(LocalizedStringKey(messageKey))
                .font(.callout)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainTabView()
        .environmentObject(PurchaseManager(startTasks: false))
}
