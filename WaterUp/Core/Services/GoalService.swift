import Foundation
import SwiftData

enum GoalServiceError: Error, Equatable {
    case noGoalConfigured
}

extension Notification.Name {
    static let waterUpGoalDidChange = Notification.Name("WaterUp.goalDidChange")
}

struct GoalService {
    let dateBoundary: DateBoundaryService
    private let saveChanges: (ModelContext) throws -> Void

    init(
        dateBoundary: DateBoundaryService = DateBoundaryService(),
        saveChanges: @escaping (ModelContext) throws -> Void = { context in
            try PersistenceService.saveChanges(in: context)
        }
    ) {
        self.dateBoundary = dateBoundary
        self.saveChanges = saveChanges
    }

    func goal(for date: Date, in context: ModelContext) throws -> DailyGoalChange {
        let dayKey = dateBoundary.dayKey(for: date)
        return try goal(forDayKey: dayKey, in: context)
    }

    func goal(forDayKey dayKey: String, in context: ModelContext) throws -> DailyGoalChange {
        let descriptor = FetchDescriptor<DailyGoalChange>(
            predicate: #Predicate { goal in
                goal.effectiveDayKey <= dayKey
            },
            sortBy: [SortDescriptor(\DailyGoalChange.effectiveDayKey, order: .reverse)]
        )

        guard let goal = try context.fetch(descriptor).first else {
            throw GoalServiceError.noGoalConfigured
        }

        return goal
    }

    func upsertToday(
        targetML: Int,
        now: Date,
        in context: ModelContext
    ) throws {
        try GoalValidator.validate(targetML: targetML)

        let dayKey = dateBoundary.dayKey(for: now)
        let descriptor = FetchDescriptor<DailyGoalChange>(
            predicate: #Predicate { goal in
                goal.effectiveDayKey == dayKey
            }
        )
        let sameDayGoals = try context.fetch(descriptor)

        if let existingGoal = sameDayGoals.first {
            existingGoal.targetML = targetML

            for duplicateGoal in sameDayGoals.dropFirst() {
                context.delete(duplicateGoal)
            }

            try persistChanges(in: context)
            return
        }

        let newGoal = DailyGoalChange(
            effectiveDayKey: dayKey,
            targetML: targetML,
            createdAt: now
        )
        context.insert(newGoal)
        try persistChanges(in: context)
    }

    private func persistChanges(in context: ModelContext) throws {
        do {
            try saveChanges(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
