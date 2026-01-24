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
                Label("Entrenamiento", systemImage: "bolt.heart")
            }

            NavigationStack {
                TabPlaceholderView(message: "Proximamente")
            }
            .tabItem {
                Label("Guardado", systemImage: "bookmark")
            }

            NavigationStack {
                TabPlaceholderView(message: "Proximamente")
            }
            .tabItem {
                Label("Seguimiento", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                TabPlaceholderView(message: "Proximamente")
            }
            .tabItem {
                Label("Ajustes", systemImage: "gear")
            }
        }
    }
}

private struct TabPlaceholderView: View {
    let message: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            Text(message)
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
