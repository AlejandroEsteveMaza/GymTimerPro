import ActivityKit
import Combine
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class LiveActivityManager: ObservableObject {
    private var activity: Activity<GymTimerAttributes>?
    private let notificationCenter = UNUserNotificationCenter.current()

    func requestNotificationAuthorizationIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("ui-testing") || args.contains("-ui_testing") {
            return
        }

        Task {
            let settings = await notificationCenter.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound])
        }
    }

    func startOrUpdate(currentSet: Int, totalSets: Int, endDate: Date, mode: GymTimerAttributes.Mode) {
        let state = GymTimerAttributes.ContentState(
            currentSet: currentSet,
            totalSets: totalSets,
            endDate: endDate,
            mode: mode
        )

        if activity == nil {
            activity = Activity<GymTimerAttributes>.activities.first
        }

        if let activity {
            Task {
                await activity.update(ActivityContent(state: state, staleDate: endDate))
            }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            scheduleEndNotification(endDate: endDate, currentSet: currentSet, totalSets: totalSets)
            return
        }

        let attributes = GymTimerAttributes(sessionID: UUID())
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endDate)
            )
        } catch {
            scheduleEndNotification(endDate: endDate, currentSet: currentSet, totalSets: totalSets)
        }
    }

    func end(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) {
        if activity == nil {
            activity = Activity<GymTimerAttributes>.activities.first
        }
        guard let activity else { return }
        Task {
            let finalContent: ActivityContent<GymTimerAttributes.ContentState>? = nil
            await activity.end(finalContent, dismissalPolicy: dismissalPolicy)
        }
        self.activity = nil
    }

    func scheduleEndNotification(endDate: Date, currentSet: Int, totalSets: Int) {
        Task {
            let settings = await notificationCenter.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = L10n.tr("notification.rest_finished.title")
            content.body = L10n.format("notification.rest_finished.body_format", currentSet, totalSets)
            content.sound = .default

            let interval = max(1, endDate.timeIntervalSince(Date()))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: "restTimer.end", content: content, trigger: trigger)

            notificationCenter.removePendingNotificationRequests(withIdentifiers: ["restTimer.end"])
            try? await notificationCenter.add(request)
        }
    }

    func cancelEndNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["restTimer.end"])
    }
}
