import XCTest
import SwiftUI
import CommonCore
import KimaiCore
@testable import businessToGo

final class ReportsPerformanceTests: XCTestCase {
    private var report: ReportsView!
    private var viewModel: ReportViewModel!
    private var preparedChart: Any?
    private var selectedDate = Date()
    private var selectedProject: Int?

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

        viewModel = ReportViewModel()
        selectedDate = monday
        selectedProject = nil
        report = ReportsView(
            timesheets: records,
            timesheetChanges: [],
            projects: [],
            activities: [],
            customers: [],
            selectedProject: Binding(get: { self.selectedProject }, set: { self.selectedProject = $0 }),
            selectedDate: Binding(get: { self.selectedDate }, set: { self.selectedDate = $0 }),
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
        viewModel = nil
        super.tearDown()
    }

    func testWeeklyChartCalculationsMatchFixture() {
        let filtered = report.timesheetsFiltered(using: viewModel)
        let records = filtered.map(\.timesheet)

        XCTAssertEqual(records.map(\.id), (0..<10_000).filter { $0 % 100 < 7 })
        XCTAssertEqual(KimaiTimesheet.totalHours(of: records), 700 * 3_600, accuracy: 0.001)
        let totals = report.weeklyTotals(for: filtered)
        for weekday in 1...7 {
            let previousTotal = KimaiTimesheet.totalHours(of: records.filter {
                $0.getBeginDate()?.getWeekday() == weekday
            }) / 3600
            XCTAssertEqual(totals[weekday], previousTotal, accuracy: 0.001)
            XCTAssertEqual(totals[weekday], 100, accuracy: 0.001)
        }
    }

    func testSwitchingWeeksAndProjectsMatchesPreviousFiltering() throws {
        _ = report.timesheetsFiltered(using: viewModel)
        selectedDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 7, to: selectedDate))
        selectedProject = 2

        let actual = report.timesheetsFiltered(using: viewModel).map(\.timesheet)
        let expected = report.timesheets.filter {
            $0.project == selectedProject && ($0.getBeginDate()?.isInMondayWeek(of: selectedDate) ?? false)
        }
        XCTAssertEqual(actual, expected)
    }

    func testPreparedDatesRefreshWhenTimesheetsChange() {
        let original = Array(report.timesheets.prefix(2))
        let first = viewModel.prepareTimesheets(original)
        var changed = original[0]
        changed.begin = "invalid"
        let updated = viewModel.prepareTimesheets([changed])

        XCTAssertNotNil(first[0].beginDate)
        XCTAssertEqual(updated.map(\.timesheet), [changed])
        XCTAssertNil(updated[0].beginDate)
        XCTAssertEqual(viewModel.prepareTimesheets(original).map(\.beginDate), first.map(\.beginDate))
    }

    func testInitialDatePreparationPerformance() {
        let records = report.timesheets
        measure(metrics: [XCTClockMetric()]) {
            preparedChart = ReportViewModel().prepareTimesheets(records)
        }
    }

    func testWeeklyChartPreparationPerformance() {
        _ = viewModel.prepareTimesheets(report.timesheets)
        let firstWeek = selectedDate
        let secondWeek = Calendar.current.date(byAdding: .day, value: 7, to: firstWeek)!
        var nextWeek = secondWeek
        // Measure selection and chart preparation while switching between cached weeks.
        // This does not render SwiftUI, query storage, or contact Kimai.
        measure(metrics: [XCTClockMetric()]) {
            selectedDate = nextWeek
            nextWeek = nextWeek == firstWeek ? secondWeek : firstWeek
            preparedChart = report.getReportChart(timesheets: report.timesheetsFiltered(using: viewModel))
        }
    }
}
