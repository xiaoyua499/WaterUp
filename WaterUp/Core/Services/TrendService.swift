import Foundation
import SwiftData

enum TrendRange: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }

    var title: String {
        "\(rawValue) 日"
    }

    var subtitle: String {
        "最近 \(rawValue) 个自然日"
    }
}

enum TrendServiceError: Error, Equatable {
    case unavailableDayRange
    case missingFirstUseDay
    case missingGoalForStatisticalDay
}

struct TrendPoint: Identifiable, Equatable {
    let date: Date
    let dayKey: String
    let effectiveHydrationML: Int
    let targetML: Int?
    let hasRecord: Bool
    let isStatisticalDay: Bool

    var id: String { dayKey }

    var hasReachedTarget: Bool {
        guard let targetML else {
            return false
        }

        return effectiveHydrationML >= targetML
    }
}

struct TrendSummary: Equatable {
    let totalEffectiveHydrationML: Int
    let reachedTargetDayCount: Int
    let averageEffectiveHydrationML: Int
    let statisticalDayCount: Int
    let recordCoveragePercent: Int
}

struct TrendPeriod: Equatable {
    let range: TrendRange
    let points: [TrendPoint]
    let summary: TrendSummary
}

struct TrendComparison: Equatable {
    let averageDifferenceML: Int
    let percentageChange: Int
}

struct TrendDashboard: Equatable {
    let period: TrendPeriod
    let comparisonWithPreviousPeriod: TrendComparison?
}

struct TrendService {
    private let calendar: Calendar
    private let dateBoundary: DateBoundaryService

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        dateBoundary = DateBoundaryService(calendar: calendar)
    }

    func dashboard(
        for range: TrendRange,
        now: Date = .now,
        in context: ModelContext
    ) throws -> TrendDashboard {
        guard let todayRange = dateBoundary.dayRange(for: now),
              let chartStart = calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: todayRange.start) else {
            throw TrendServiceError.unavailableDayRange
        }

        let chartInterval = DateInterval(start: chartStart, end: todayRange.end)
        let comparisonStart = calendar.date(byAdding: .day, value: -range.rawValue, to: chartStart)
        let fetchStart = comparisonStart ?? chartStart
        let recordsByDayKey = try recordsByDayKey(
            in: DateInterval(start: fetchStart, end: chartInterval.end),
            context: context
        )
        let firstUseDayKey = try firstUseDayKey(in: context)
        let goals = try goals(through: chartInterval.end, in: context)
        let currentPoints = try points(
            in: chartInterval,
            firstUseDayKey: firstUseDayKey,
            recordsByDayKey: recordsByDayKey,
            goals: goals
        )
        let period = TrendPeriod(
            range: range,
            points: currentPoints,
            summary: summary(for: currentPoints)
        )

        guard range == .sevenDays, let comparisonStart else {
            return TrendDashboard(period: period, comparisonWithPreviousPeriod: nil)
        }

        let comparisonInterval = DateInterval(start: comparisonStart, end: chartStart)
        let comparisonPoints = try points(
            in: comparisonInterval,
            firstUseDayKey: firstUseDayKey,
            recordsByDayKey: recordsByDayKey,
            goals: goals
        )
        let comparisonSummary = summary(for: comparisonPoints)
        let comparison = comparison(
            currentSummary: period.summary,
            previousSummary: comparisonSummary
        )

        return TrendDashboard(period: period, comparisonWithPreviousPeriod: comparison)
    }

    private func points(
        in interval: DateInterval,
        firstUseDayKey: String,
        recordsByDayKey: [String: [HydrationRecord]],
        goals: [DailyGoalChange]
    ) throws -> [TrendPoint] {
        var result = [TrendPoint]()
        let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0

        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else {
                continue
            }

            let dayKey = dateBoundary.dayKey(for: date)
            let records = recordsByDayKey[dayKey] ?? []
            let isStatisticalDay = dayKey >= firstUseDayKey
            let targetML: Int?

            if isStatisticalDay {
                guard let goal = goal(forDayKey: dayKey, from: goals) else {
                    throw TrendServiceError.missingGoalForStatisticalDay
                }

                targetML = goal.targetML
            } else {
                targetML = nil
            }

            var totalEffectiveHydrationML = 0
            for record in records {
                totalEffectiveHydrationML += record.effectiveHydrationML
            }

            result.append(
                TrendPoint(
                    date: date,
                    dayKey: dayKey,
                    effectiveHydrationML: totalEffectiveHydrationML,
                    targetML: targetML,
                    hasRecord: !records.isEmpty,
                    isStatisticalDay: isStatisticalDay
                )
            )
        }

        return result
    }

    private func summary(for points: [TrendPoint]) -> TrendSummary {
        let statisticalPoints = points.filter(\.isStatisticalDay)
        var totalEffectiveHydrationML = 0
        var reachedTargetDayCount = 0
        var recordDayCount = 0

        for point in statisticalPoints {
            totalEffectiveHydrationML += point.effectiveHydrationML

            if point.hasReachedTarget {
                reachedTargetDayCount += 1
            }

            if point.hasRecord {
                recordDayCount += 1
            }
        }

        let statisticalDayCount = statisticalPoints.count
        let average: Int
        let coverage: Int

        if statisticalDayCount == 0 {
            average = 0
            coverage = 0
        } else {
            average = Int((Double(totalEffectiveHydrationML) / Double(statisticalDayCount)).rounded())
            coverage = Int((Double(recordDayCount) / Double(statisticalDayCount) * 100).rounded())
        }

        return TrendSummary(
            totalEffectiveHydrationML: totalEffectiveHydrationML,
            reachedTargetDayCount: reachedTargetDayCount,
            averageEffectiveHydrationML: average,
            statisticalDayCount: statisticalDayCount,
            recordCoveragePercent: coverage
        )
    }

    private func comparison(
        currentSummary: TrendSummary,
        previousSummary: TrendSummary
    ) -> TrendComparison? {
        guard previousSummary.statisticalDayCount > 0,
              previousSummary.averageEffectiveHydrationML > 0 else {
            return nil
        }

        let difference = currentSummary.averageEffectiveHydrationML - previousSummary.averageEffectiveHydrationML
        let percentage = Int(
            (Double(difference) / Double(previousSummary.averageEffectiveHydrationML) * 100).rounded()
        )

        return TrendComparison(
            averageDifferenceML: difference,
            percentageChange: percentage
        )
    }

    private func firstUseDayKey(in context: ModelContext) throws -> String {
        let metadata = try context.fetch(FetchDescriptor<AppMetadata>())

        guard let firstUseDayKey = metadata.first?.firstUseDayKey else {
            throw TrendServiceError.missingFirstUseDay
        }

        return firstUseDayKey
    }

    private func recordsByDayKey(
        in interval: DateInterval,
        context: ModelContext
    ) throws -> [String: [HydrationRecord]] {
        let start = interval.start
        let end = interval.end
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
        let dayKey = dateBoundary.dayKey(for: date.addingTimeInterval(-1))
        let descriptor = FetchDescriptor<DailyGoalChange>(
            predicate: #Predicate { goal in
                goal.effectiveDayKey <= dayKey
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
}
