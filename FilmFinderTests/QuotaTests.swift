import Foundation
import Testing
@testable import FilmFinder

@Suite struct QuotaTests {
    @Test func usedFractionIsTheShareOfTheLimit() {
        #expect(Quota(used: 3, limit: 10, resetsAt: Date()).usedFraction == 0.3)
    }

    @Test func usedFractionIsClampedToOne() {
        #expect(Quota(used: 12, limit: 10, resetsAt: Date()).usedFraction == 1)
    }

    @Test func usedFractionIsZeroWhenLimitIsZero() {
        #expect(Quota(used: 0, limit: 0, resetsAt: Date()).usedFraction == 0)
    }
}
