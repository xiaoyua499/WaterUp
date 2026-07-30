import SwiftData

enum PersistenceService {
    static func saveChanges(in context: ModelContext) throws {
        guard context.hasChanges else {
            return
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
