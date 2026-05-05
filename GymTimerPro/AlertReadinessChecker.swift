import Combine
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class AlertReadinessChecker: ObservableObject {

    enum Warning: Equatable {
        case soundDisabled
        case timeSensitiveDisabled
    }

    @Published private(set) var activeWarning: Warning?

    private var checkTask: Task<Void, Never>?

    func check() {
        checkTask?.cancel()
        checkTask = Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard !Task.isCancelled else { return }

            if settings.soundSetting == .disabled {
                activeWarning = .soundDisabled
                return
            }

            if settings.timeSensitiveSetting == .disabled {
                activeWarning = .timeSensitiveDisabled
                return
            }

            activeWarning = nil
        }
    }
}
