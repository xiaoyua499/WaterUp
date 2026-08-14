import Foundation
import SwiftData

enum HistoryServiceError: Error, Equatable {
    case unavailableMonthRange
    case missingGoalForRecordedDay
}

enum HistoryDayState: Equatable {
    case noData
    case belowTarget
    case reachedTarget
}

struct HistoryCalendarDay: Identifiable, Equatable {
    let id: String
    let date: Date?
    let dayNumber: Int?
    let state: HistoryDayState?
    let isToday: Bool
    let isFuture: Bool
}

struct HistoryMonth: Equatable {
    let monthStart: Date
    let days: [HistoryCalendarDay]
}

struct HistoryDayDetail {
    let date: Date
    let summary: DailyHydrationSummary
    let records: [HydrationRecord]
}

struct HistoryService {
    private let calendar: Calendar
    private let dateBoundary: DateBoundaryService

    init(calendar: Calendar = .autoupdatingCurrent) {
        var mondayFirstCalendar = calendar
        mondayFirstCalendar.firstWeekday = 2
        self.calendar = mondayFirstCalendar
        dateBoundary = DateBoundaryService(calendar: mondayFirstCalendar)
    }

    func month(for month: Date, now: Date = .now, in context: ModelContext) throws -> HistoryMonth {
        guard let monthRange = monthRange(for: month) else {
            throw HistoryServiceError.unavailableMonthRange
        }

        let recordsByDayKey = try recordsByDayKey(in: monthRange, context: context)
        let goals = try goals(through: monthRange.end, in: context)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthRange.start)?.count ?? 0
        let leadingEmptyDays = leadingEmptyDayCount(for: monthRange.start)
        var days = [HistoryCalendarDay]()

        for index in 0..<leadingEmptyDays {
            days.append(
                HistoryCalendarDay(
                    id: "empty-\(index)",
                    date: nil,
                    dayNumber: nil,
                    state: nil,
                    isToday: false,
                    isFuture: false
                )
            )
        }

        for dayOffset in 0..<daysInMonth {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: monthRange.start) else {
                continue
            }

            let dayKey = dateBoundary.dayKey(for: date)
            let records = recordsByDayKey[dayKey] ?? []
            let dayStart = dateBoundary.dayRange(for: date)?.start ?? date
            let todayStart = dateBoundary.dayRange(for: now)?.start ?? now
            let isFuture = dayStart > todayStart
            let state: HistoryDayState?

            if isFuture {
                state = nil
            } else if records.isEmpty {
                state = .noData
            } else {
                guard let goal = goal(forDayKey: dayKey, from: goals) else {
                    throw HistoryServiceError.missingGoalForRecordedDay
                }

                let totalEffectiveHydration = records.reduce(0) { partialResult, record in
                    partialResult + record.effectiveHydrationML
                }
                state = totalEffectiveHydration >= goal.targetML ? .reachedTarget : .belowTarget
            }

            days.append(
                HistoryCalendarDay(
                    id: dayKey,
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    state: state,
                    isToday: calendar.isDate(date, inSameDayAs: now),
                    isFuture: isFuture
                )
            )
        }

        while days.count % 7 != 0 {
            days.append(
                HistoryCalendarDay(
                    id: "trailing-\(days.count)",
                    date: nil,
                    dayNumber: nil,
                    state: nil,
                    isToday: false,
                    isFuture: false
                )
            )
        }

        return HistoryMonth(monthStart: monthRange.start, days: days)
    }

    func detail(for date: Date, in context: ModelContext) throws -> HistoryDayDetail {
        let recordQuery = HydrationRecordQueryService(dateBoundary: dateBoundary)
        let records = try recordQuery.records(on: date, in: context)
        let goalService = GoalService(dateBoundary: dateBoundary)
        let goal = try goalService.goal(for: date, in: context)
        var totalVolume = 0
        var totalEffectiveHydration = 0

        for record in records {
            totalVolume += record.volumeML
            totalEffectiveHydration += record.effectiveHydrationML
        }

        let summary = DailyHydrationSummary(
            dayKey: dateBoundary.dayKey(for: date),
            targetML: goal.targetML,
            totalVolumeML: totalVolume,
            totalEffectiveHydrationML: totalEffectiveHydration
        )

        return HistoryDayDetail(date: date, summary: summary, records: records)
    }

    private func monthRange(for month: Date) -> DateInterval? {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return nil
        }

        return interval
    }

    private func recordsByDayKey(
        in range: DateInterval,
        context: ModelContext
    ) throws -> [String: [HydrationRecord]] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<HydrationRecord>(
            predicate: #Predicate { record in
                record.consumedAt >= start && record.consumedAt < end
            }
        )
        let records = try context.fetch(descriptor)
        var result = [String: [HydrationRecord]]()

        for record in records {
            let dayKey = dateBoundary.dayKey(for: record.consumedAt)
            result[dayKey, default: []].append(record)
        }

        return result
    }

    private func goals(through date: Date, in context: ModelContext) throws -> [DailyGoalChange] {
        let lastDayKey = dateBoundary.dayKey(for: date.addingTimeInterval(-1))
        let descriptor = FetchDescriptor<DailyGoalChange>(
            predicate: #Predicate { goal in
                goal.effectiveDayKey <= lastDayKey
            },
            sortBy: [SortDescriptor(\DailyGoalChange.effectiveDayKey, order: .forward)]
        )

        return try context.fetch(descriptor)
    }

    private func goal(forDayKey dayKey: String, from goals: [DailyGoalChange]) -> DailyGoalChange? {
        var matchingGoal: DailyGoalChange?

        for goal in goals {
            if goal.effectiveDayKey > dayKey {
                break
            }

            matchingGoal = goal
        }

        return matchingGoal
    }

    private func leadingEmptyDayCount(for monthStart: Date) -> Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}
