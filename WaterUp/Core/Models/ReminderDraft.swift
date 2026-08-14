import Foundation

enum ReminderDraftValidationError: Error, Equatable {
    case invalidTimeWindow
    case invalidInterval

    var message: String {
        switch self {
        case .invalidTimeWindow:
            return "结束时间需晚于起始时间"
        case .invalidInterval:
            return "请选择有效的提醒间隔"
        }
    }
}

struct ReminderScheduleConfiguration: Equatable {
    static let allowedIntervals = [30, 60, 90, 120, 180]

    var isEnabled: Bool
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
    var intervalMinutes: Int

    init(
        isEnabled: Bool,
        startMinuteOfDay: Int,
        endMinuteOfDay: Int,
        intervalMinutes: Int
    ) throws {
        self.isEnabled = isEnabled
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
        self.intervalMinutes = intervalMinutes
        try validate()
    }

    init(configuration: ReminderConfiguration) throws {
        try self.init(
            isEnabled: configuration.isEnabled,
            startMinuteOfDay: configuration.startMinuteOfDay,
            endMinuteOfDay: configuration.endMinuteOfDay,
            intervalMinutes: configuration.intervalMinutes
        )
    }

    func validate() throws {
        guard startMinuteOfDay >= 0,
              endMinuteOfDay < 24 * 60,
              startMinuteOfDay < endMinuteOfDay else {
            throw ReminderDraftValidationError.invalidTimeWindow
        }

        guard Self.allowedIntervals.contains(intervalMinutes) else {
            throw ReminderDraftValidationError.invalidInterval
        }
    }
}
