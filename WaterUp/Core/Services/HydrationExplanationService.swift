import SwiftData

enum HydrationExplanationServiceError: Error, Equatable {
    case appMetadataUnavailable
    case multipleAppMetadataRecords
}

struct HydrationExplanationService {
    func shouldShow(in context: ModelContext) throws -> Bool {
        let metadata = try fetchMetadata(in: context)
        return !metadata.hasShownHydrationExplanation
    }

    func markAsShown(in context: ModelContext) throws {
        let metadata = try fetchMetadata(in: context)
        metadata.hasShownHydrationExplanation = true
        try PersistenceService.saveChanges(in: context)
    }

    private func fetchMetadata(in context: ModelContext) throws -> AppMetadata {
        let metadata = try context.fetch(FetchDescriptor<AppMetadata>())

        guard metadata.count == 1 else {
            if metadata.isEmpty {
                throw HydrationExplanationServiceError.appMetadataUnavailable
            }

            throw HydrationExplanationServiceError.multipleAppMetadataRecords
        }

        return metadata[0]
    }
}
