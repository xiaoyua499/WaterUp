import XCTest
@testable import WaterUp

final class WaterUpTests: XCTestCase {
    func testPrimaryTabsUseDistinctTitles() {
        let tabs: [AppTab] = [.today, .history, .settings]
        let titles = Set(tabs.map(\.title))

        XCTAssertEqual(titles.count, 3)
    }
}
