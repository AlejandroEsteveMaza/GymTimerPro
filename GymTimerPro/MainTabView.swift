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
                RoutinesRootView()
            }
            .proLockedPreview(
                isLocked: !purchaseManager.isPro,
                titleKey: "pro.locked.routines.title",
                messageKey: "pro.locked.message",
                actionTitleKey: "pro.locked.unlock",
                action: { isPresentingPaywall = true }
            )
            .tabItem {
                Label("tab.routines", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                ProgramProgressView()
            }
            .proLockedPreview(
                isLocked: !purchaseManager.isPro,
                titleKey: "pro.locked.progress.title",
                messageKey: "pro.locked.message",
                actionTitleKey: "pro.locked.unlock",
                action: { isPresentingPaywall = true }
            )
            .tabItem {
                Label("tab.progress", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                SettingsRootView()
            }
            .proLockedPreview(
                isLocked: !purchaseManager.isPro,
                titleKey: "pro.locked.settings.title",
                messageKey: "pro.locked.message",
                actionTitleKey: "pro.locked.unlock",
                action: { isPresentingPaywall = true }
            )
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

private extension View {
    func proLockedPreview(
        isLocked: Bool,
        titleKey: String,
        messageKey: String,
        actionTitleKey: String,
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            ProLockedPreviewModifier(
                isLocked: isLocked,
                titleKey: titleKey,
                messageKey: messageKey,
                actionTitleKey: actionTitleKey,
                action: action
            )
        )
    }
}

private struct ProLockedPreviewModifier: ViewModifier {
    let isLocked: Bool
    let titleKey: String
    let messageKey: String
    let actionTitleKey: String
    let action: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isLocked ? 10 : 0)
                .saturation(isLocked ? 0.9 : 1)
                .accessibilityHidden(isLocked)
                .allowsHitTesting(!isLocked)

            if isLocked {
                ProLockedPreviewOverlay(
                    titleKey: titleKey,
                    messageKey: messageKey,
                    actionTitleKey: actionTitleKey,
                    action: action
                )
            }
        }
    }
}

private struct ProLockedPreviewOverlay: View {
    let titleKey: String
    let messageKey: String
    let actionTitleKey: String
    let action: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onTapGesture { }
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .semibold))
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
            .padding(20)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)
        }
        .ignoresSafeArea()
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
        .modelContainer(for: [Routine.self, RoutineClassification.self, WorkoutCompletion.self, GoalSettings.self], inMemory: true)
}
