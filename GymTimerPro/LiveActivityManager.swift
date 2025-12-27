import ActivityKit
import Combine
import Foundation
import UserNotifications

@MainActor
final class LiveActivityManager: ObservableObject {
    private var activity: Activity<GymTimerAttributes>?
    private let notificationCenter = UNUserNotificationCenter.current()

    func requestNotificationAuthorizationIfNeeded() {
        notificationCenter.getNotificationSettings { [notificationCenter] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
            await activity.end(dismissalPolicy: dismissalPolicy)
        }
        self.activity = nil
    }

    func scheduleEndNotification(endDate: Date, currentSet: Int, totalSets: Int) {
        notificationCenter.getNotificationSettings { [notificationCenter] settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Descanso terminado"
            content.body = "Serie \(currentSet)/\(totalSets)"
            content.sound = .default

            let interval = max(1, endDate.timeIntervalSince(Date()))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: "restTimer.end", content: content, trigger: trigger)

            notificationCenter.removePendingNotificationRequests(withIdentifiers: ["restTimer.end"])
            notificationCenter.add(request)
        }
    }

    func cancelEndNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["restTimer.end"])
    }
}
