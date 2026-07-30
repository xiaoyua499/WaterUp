import Foundation

struct DateBoundaryService {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func dayRange(for date: Date) -> DateInterval? {
        let start = calendar.startOfDay(for: date)

        guard let nextStart = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }

        return DateInterval(start: start, end: nextStart)
    }
}
