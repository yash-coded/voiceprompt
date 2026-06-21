import Testing
@testable import Murmur

@Suite("HistoryRetention")
struct HistoryRetentionTests {

    @Test("maps each option to a cutoff in days")
    func dayMapping() {
        #expect(HistoryRetention.off.days == 0)
        #expect(HistoryRetention.sevenDays.days == 7)
        #expect(HistoryRetention.thirtyDays.days == 30)
        #expect(HistoryRetention.forever.days == nil)
    }

    @Test("every option has a label")
    func labelsNonEmpty() {
        #expect(HistoryRetention.allCases.allSatisfy { !$0.label.isEmpty })
    }
}
