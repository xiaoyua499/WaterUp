import Foundation

struct GoalDraft: Equatable {
    static let minimumTargetML = 500
    static let maximumTargetML = 5_000
    static let stepML = 100

    private(set) var targetML: Int

    init(targetML: Int) throws {
        try GoalValidator.validate(targetML: targetML)
        self.targetML = targetML
    }

    var canDecrease: Bool {
        targetML > Self.minimumTargetML
    }

    var canIncrease: Bool {
        targetML < Self.maximumTargetML
    }

    mutating func decrease() {
        guard canDecrease else {
            return
        }

        targetML -= Self.stepML
    }

    mutating func increase() {
        guard canIncrease else {
            return
        }

        targetML += Self.stepML
    }
}
