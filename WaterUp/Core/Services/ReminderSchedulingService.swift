import Foundation
import SwiftData
import UserNotifications

extension Notification.Name {
    static let waterUpRecordDidChange = Notification.Name("WaterUp.recordDidChange")
    static let waterUpReminderConfigurationDidChange = Notification.Name("WaterUp.reminderConfigurationDidChange")
}

enum ReminderConfigurationServiceError: Error, Equatable {
    case configurationNotFound
    case multipleConfigurations
}

struct ReminderConfigurationService {
    private let saveChanges: (ModelContext) throws -> Void

    init(
        saveChanges: @escaping (ModelContext) throws -> Void = { context in
            try PersistenceService.saveChanges(in: context)
        }
    ) {
        self.saveChanges = saveChanges
    }

    func configuration(in context: ModelContext) throws -> ReminderConfiguration {
        let configurations = try context.fetch(FetchDescriptor<ReminderConfiguration>())

        guard configurations.count == 1 else {
            if configurations.isEmpty {
                throw ReminderConfigurationServiceError.configurationNotFound
            }

            throw ReminderConfigurationServiceError.multipleConfigurations
        }

        return configurations[0]
    }

    func save(
        configuration: ReminderScheduleConfiguration,
        in context: ModelContext
    ) throws {
        let storedConfiguration = try self.configuration(in: context)
        storedConfiguration.isEnabled = configuration.isEnabled
        storedConfiguration.startMinuteOfDay = configuration.startMinuteOfDay
        storedConfiguration.endMinuteOfDay = configuration.endMinuteOfDay
        storedConfiguration.intervalMinutes = configuration.intervalMinutes
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

struct ReminderNotificationService {
    static let identifierPrefix = "waterup.reminder."

    private let notificationCenter: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    @MainActor
    func replaceReminderRequests(for dates: [Date]) async throws {
        let existingRequests = await pendingWaterUpRequests()
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: existingRequests.map(\.identifier)
        )

        do {
            for date in dates {
                let request = makeRequest(for: date)
                try await notificationCenter.add(request)
            }
        } catch {
            // Revert the replacement so a failed partial plan never becomes the active plan.
            await cancelWaterUpRequests()
            for request in existingRequests {
                try? await notificationCenter.add(request)
            }
            throw error
        }
    }

    @MainActor
    func cancelWaterUpRequests() async {
        let requests = await pendingWaterUpRequests()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
    }

    @MainActor
    private func pendingWaterUpRequests() async -> [UNNotificationRequest] {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.filter { request in
            request.identifier.hasPrefix(Self.identifierPrefix)
        }
    }

    private func makeRequest(for date: Date) -> UNNotificationRequest {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = "该喝水啦"
        content.body = "喝一杯，继续完成今日补水目标。"
        content.sound = .default

        return UNNotificationRequest(
            identifier: identifier(for: date),
            content: content,
            trigger: trigger
        )
    }

    private func identifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        return String(format: "%@%04d%02d%02d-%02d%02d", Self.identifierPrefix, year, month, day, hour, minute)
    }
}

enum ReminderSchedulingResult: Equatable {
    case disabled
    case authorizationUnavailable
    case scheduled(nextReminderDate: Date?)
}

struct ReminderSchedulingService {
    private let configurationService: ReminderConfigurationService
    private let authorizationService: NotificationAuthorizationService
    private let notificationService: ReminderNotificationService
    private let summaryService: HydrationSummaryService
    private let calculator: ReminderScheduleCalculator

    init(
        configurationService: ReminderConfigurationService = ReminderConfigurationService(),
        authorizationService: NotificationAuthorizationService = NotificationAuthorizationService(),
        notificationService: ReminderNotificationService = ReminderNotificationService(),
        summaryService: HydrationSummaryService = HydrationSummaryService(),
        calculator: ReminderScheduleCalculator = ReminderScheduleCalculator()
    ) {
        self.configurationService = configurationService
        self.authorizationService = authorizationService
        self.notificationService = notificationService
        self.summaryService = summaryService
        self.calculator = calculator
    }

    @MainActor
    func synchronize(in context: ModelContext, now: Date = .now) async throws -> ReminderSchedulingResult {
        let storedConfiguration = try configurationService.configuration(in: context)

        guard storedConfiguration.isEnabled else {
            await notificationService.cancelWaterUpRequests()
            return .disabled
        }

        let authorizationStatus = await authorizationService.currentStatus()
        guard authorizationStatus.canScheduleReminders else {
            storedConfiguration.isEnabled = false
            try PersistenceService.saveChanges(in: context)
            await notificationService.cancelWaterUpRequests()
            return .authorizationUnavailable
        }

        let configuration = try ReminderScheduleConfiguration(configuration: storedConfiguration)
        let dates = try calculator.reminderDates(configuration: configuration, now: now) { date in
            let summary = try summaryService.summary(for: date, in: context)
            return summary.totalEffectiveHydrationML >= summary.targetML
        }

        try await notificationService.replaceReminderRequests(for: dates)
        storedConfiguration.lastScheduledAt = now
        try PersistenceService.saveChanges(in: context)

        return .scheduled(nextReminderDate: dates.first)
    }
}
