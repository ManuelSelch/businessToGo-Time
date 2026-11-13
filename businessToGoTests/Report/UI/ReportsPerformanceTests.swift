import XCTest
import SwiftUI
import CommonCore
import KimaiCore
@testable import businessToGo

final class ReportsPerformanceTests: XCTestCase {
    private var report: ReportsView!
    private var preparedChart: Any?

    override func setUpWithError() throws {
        // 100 entries per day over 100 days; the selected week contains 700 hours.
        // Fixture creation and view setup are deliberately outside the timed block.
        let calendar = Calendar.current
        let monday = Date(timeIntervalSince1970: 1_736_164_800).mondayWeekStart()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone

        let records = try (0..<10_000).map { id in
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: id % 100, to: monday))
            let begin = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day))
            var record = KimaiTimesheet()
            record.id = id
            record.project = id % 5
            record.begin = formatter.string(from: begin)
            record.end = formatter.string(from: begin.addingTimeInterval(3_600))
            return record
        }

        report = ReportsView(
            timesheets: records,
            timesheetChanges: [],
            projects: [],
            activities: [],
            customers: [],
            selectedProject: .constant(nil),
            selectedDate: .constant(monday),
            selectedReportType: .constant(.week),
            calendarTapped: {},
            filterTapped: {},
            playTapped: {},
            editTapped: { _ in },
            deleteTapped: { _ in }
        )
    }

    override func tearDown() {
        preparedChart = nil
        report = nil
        super.tearDown()
    }

    func testWeeklyChartCalculationsMatchFixture() {
        let filtered = report.timesheetsFiltered

        XCTAssertEqual(filtered.map(\.id), (0..<10_000).filter { $0 % 100 < 7 })
        XCTAssertEqual(KimaiTimesheet.totalHours(of: filtered), 700 * 3_600, accuracy: 0.001)
        let totals = report.weeklyTotals(for: filtered)
        for weekday in 1...7 {
            let previousTotal = KimaiTimesheet.totalHours(of: filtered.filter {
                $0.getBeginDate()?.getWeekday() == weekday
            }) / 3600
            XCTAssertEqual(totals[weekday], previousTotal, accuracy: 0.001)
            XCTAssertEqual(totals[weekday], 100, accuracy: 0.001)
        }
    }

    func testWeeklyChartPreparationPerformance() {
        // Measure the production chart path, including selection filtering.
        // Retain the result so the compiler cannot discard chart preparation.
        // This does not render SwiftUI, query storage, or contact Kimai.
        measure(metrics: [XCTClockMetric()]) {
            preparedChart = report.getReportChart(timesheets: report.timesheetsFiltered)
        }
    }
}
