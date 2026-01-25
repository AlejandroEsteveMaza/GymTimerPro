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
    @StateObject private var usageLimiter = DailyUsageLimiter(dailyLimit: 19)
    @State private var isPresentingPaywall = false

    var body: some View {
        TabView {
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("tab.training", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                if purchaseManager.isPro {
                    RoutinesRootView()
                } else {
                    LockedFeatureView(
                        titleKey: "pro.locked.routines.title",
                        messageKey: "pro.locked.message",
                        actionTitleKey: "pro.locked.unlock",
                        action: { isPresentingPaywall = true }
                    )
                }
            }
            .tabItem {
                Label("tab.routines", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                if purchaseManager.isPro {
                    TabPlaceholderView(messageKey: "placeholder.coming_soon")
                } else {
                    LockedFeatureView(
                        titleKey: "pro.locked.progress.title",
                        messageKey: "pro.locked.message",
                        actionTitleKey: "pro.locked.unlock",
                        action: { isPresentingPaywall = true }
                    )
                }
            }
            .tabItem {
                Label("tab.progress", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                if purchaseManager.isPro {
                    TabPlaceholderView(messageKey: "placeholder.coming_soon")
                } else {
                    LockedFeatureView(
                        titleKey: "pro.locked.settings.title",
                        messageKey: "pro.locked.message",
                        actionTitleKey: "pro.locked.unlock",
                        action: { isPresentingPaywall = true }
                    )
                }
            }
            .tabItem {
                Label("tab.settings", systemImage: "gear")
            }
        }
        .sheet(isPresented: $isPresentingPaywall) {
            PaywallView(
                dailyLimit: usageLimiter.status.dailyLimit,
                consumedToday: usageLimiter.status.consumedToday,
                accentColor: Theme.primaryButton
            )
            .environmentObject(purchaseManager)
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

private struct LockedFeatureView: View {
    let titleKey: String
    let messageKey: String
    let actionTitleKey: String
    let action: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(LocalizedStringKey(titleKey))
                    .font(.headline)
                    .foregroundStyle(Color(uiColor: .label))
                Text(LocalizedStringKey(messageKey))
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .multilineTextAlignment(.center)
                Button(action: action) {
                    Text(LocalizedStringKey(actionTitleKey))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(Color(uiColor: .systemBlue))
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainTabView()
        .environmentObject(PurchaseManager(startTasks: false))
        .environmentObject(RoutineSelectionStore())
        .modelContainer(for: Routine.self, inMemory: true)
}
