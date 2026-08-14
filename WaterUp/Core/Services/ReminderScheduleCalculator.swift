import Foundation

struct ReminderScheduleCalculator {
    static let maximumPendingRequestCount = 60
    static let planningDayCount = 14

    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func reminderDates(
        configuration: ReminderScheduleConfiguration,
        now: Date,
        isGoalReached: (Date) throws -> Bool
    ) throws -> [Date] {
        guard configuration.isEnabled else {
            return []
        }

        var dates: [Date] = []
        let today = calendar.startOfDay(for: now)

        for dayOffset in 0..<Self.planningDayCount {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            if try isGoalReached(day) {
                continue
            }

            var minuteOfDay = configuration.startMinuteOfDay
            while minuteOfDay <= configuration.endMinuteOfDay {
                guard let date = calendar.date(byAdding: .minute, value: minuteOfDay, to: day) else {
                    break
                }

                if date > now {
                    dates.append(date)
                }

                if dates.count == Self.maximumPendingRequestCount {
                    return dates
                }

                minuteOfDay += configuration.intervalMinutes
            }
        }

        return dates
    }
}
