import UserNotifications

enum ReminderAuthorizationStatus: Equatable {
    case notDetermined
    case authorized
    case provisional
    case denied

    var canScheduleReminders: Bool {
        switch self {
        case .authorized, .provisional:
            return true
        case .notDetermined, .denied:
            return false
        }
    }
}

struct NotificationAuthorizationService {
    private let notificationCenter: UNUserNotificationCenter

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    @MainActor
    func currentStatus() async -> ReminderAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .notDetermined:
            return .notDetermined
        case .denied, .ephemeral:
            return .denied
        @unknown default:
            return .denied
        }
    }

    @MainActor
    func requestAuthorization() async -> ReminderAuthorizationStatus {
        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return await currentStatus()
        }

        return await currentStatus()
    }
}
