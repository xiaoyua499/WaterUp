import Foundation

enum HydrationValidationError: Error, Equatable {
    case invalidVolumeML
    case invalidWaterRatioPercent
}

enum GoalValidationError: Error, Equatable {
    case invalidTargetML
}

enum HydrationCalculator {
    static func effectiveHydrationML(
        volumeML: Int,
        waterRatioPercent: Int
    ) throws -> Int {
        guard (1...5_000).contains(volumeML) else {
            throw HydrationValidationError.invalidVolumeML
        }

        guard (0...100).contains(waterRatioPercent) else {
            throw HydrationValidationError.invalidWaterRatioPercent
        }

        return (volumeML * waterRatioPercent + 50) / 100
    }
}

enum GoalValidator {
    static func validate(targetML: Int) throws {
        let isInRange = (500...5_000).contains(targetML)
        let usesHundredMilliliterStep = targetML % 100 == 0

        guard isInRange, usesHundredMilliliterStep else {
            throw GoalValidationError.invalidTargetML
        }
    }
}
