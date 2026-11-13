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
        let result = report.reportResult(using: viewModel)
        let records = result.timesheets

        XCTAssertEqual(records.map(\.id), (0..<10_000).filter { $0 % 100 < 7 })
        XCTAssertEqual(KimaiTimesheet.totalHours(of: records), 700 * 3_600, accuracy: 0.001)
        let totals = result.weeklyTotals
        for weekday in 1...7 {
            let previousTotal = KimaiTimesheet.totalHours(of: records.filter {
                $0.getBeginDate()?.getWeekday() == weekday
            }) / 3600
            XCTAssertEqual(totals[weekday], previousTotal, accuracy: 0.001)
            XCTAssertEqual(totals[weekday], 100, accuracy: 0.001)
        }
        XCTAssertEqual(result.chartBuckets.map(\.hours), Array(repeating: 100, count: 7))
    }

    func testSwitchingWeeksAndProjectsMatchesPreviousFiltering() throws {
        _ = report.reportResult(using: viewModel)
        selectedDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 7, to: selectedDate))
        selectedProject = 2

        let actual = report.reportResult(using: viewModel).timesheets
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

    func testCachedReportTracksRunningAndInvalidEndEntries() throws {
        let begin = try XCTUnwrap(report.timesheets[0].getBeginDate())
        var running = report.timesheets[0]
        running.end = nil
        var invalidEnd = report.timesheets[0]
        invalidEnd.id = 20_000
        invalidEnd.end = "invalid"
        let records = [report.timesheets[0], running, invalidEnd]
        let first = viewModel.reportResult(records: records, date: selectedDate, project: nil, type: .week, now: begin.addingTimeInterval(7_200))
        let later = viewModel.reportResult(records: records, date: selectedDate, project: nil, type: .week, now: begin.addingTimeInterval(10_800))
        let weekday = try XCTUnwrap(begin.getWeekday())

        XCTAssertTrue(first.hasRunningEntries)
        XCTAssertEqual(first.totalDuration, 5 * 3_600, accuracy: 0.001)
        XCTAssertEqual(later.totalDuration, 7 * 3_600, accuracy: 0.001)
        XCTAssertEqual(first.weeklyTotals[weekday], 5, accuracy: 0.001)
        XCTAssertEqual(later.weeklyTotals[weekday], 7, accuracy: 0.001)
        let bucketIndex = (weekday + 5) % 7
        XCTAssertEqual(first.chartBuckets[bucketIndex].hours, 5, accuracy: 0.001)
        XCTAssertEqual(later.chartBuckets[bucketIndex].hours, 7, accuracy: 0.001)
    }

    func testReportCacheInvalidatesOnRecordAndSelectionChanges() throws {
        let original = Array(report.timesheets.prefix(8))
        let first = viewModel.reportResult(records: original, date: selectedDate, project: nil, type: .week)
        let filtered = viewModel.reportResult(records: original, date: selectedDate, project: 2, type: .week)
        let nextWeek = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 7, to: selectedDate))
        let next = viewModel.reportResult(records: original, date: nextWeek, project: nil, type: .week)
        var edited = original[0]
        edited.end = nil
        let changed = viewModel.reportResult(records: [edited], date: selectedDate, project: nil, type: .week)

        XCTAssertEqual(first.timesheets.count, 7)
        XCTAssertEqual(filtered.timesheets.map(\.project), [2])
        XCTAssertEqual(next.timesheets.map(\.id), [7])
        XCTAssertNil(changed.timesheets.first?.end)
        XCTAssertTrue(changed.hasRunningEntries)
        let stopped = viewModel.reportResult(records: [original[0]], date: selectedDate, project: nil, type: .week)
        XCTAssertFalse(stopped.hasRunningEntries)
        XCTAssertEqual(stopped.totalDuration, 3_600, accuracy: 0.001)
    }

    func testCustomerAndTeamFiltersCombineAndInvalidateCache() {
        var customer = KimaiCustomer.new
        customer.id = 10
        customer.teams = [7]
        var project = KimaiProject.new
        project.id = 0
        project.customer = 10
        let records = Array(report.timesheets.prefix(7))

        let matching = viewModel.reportResult(records: records, date: selectedDate, project: nil, type: .week, customer: 10, team: 7, projects: [project], customers: [customer])
        let unmatched = viewModel.reportResult(records: records, date: selectedDate, project: nil, type: .week, customer: 10, team: 8, projects: [project], customers: [customer])

        XCTAssertEqual(matching.timesheets.map(\.project), [0, 0])
        XCTAssertEqual(matching.totalDuration, 7200, accuracy: 0.001)
        XCTAssertTrue(unmatched.timesheets.isEmpty)
        XCTAssertEqual(unmatched.chartBuckets.reduce(0) { $0 + $1.hours }, 0)

        let conflictingProject = viewModel.reportResult(records: records, date: selectedDate, project: 1, type: .week, customer: 10, team: 7, projects: [project], customers: [customer])
        XCTAssertTrue(conflictingProject.timesheets.isEmpty)

        customer.teams = [8]
        let changedRelationship = viewModel.reportResult(records: records, date: selectedDate, project: nil, type: .week, customer: 10, team: 8, projects: [project], customers: [customer])
        XCTAssertEqual(changedRelationship.timesheets.map(\.project), [0, 0])
        let grouped = viewModel.groupRecords(records: changedRelationship.timesheets, projects: [project], customers: [customer])
        XCTAssertEqual(grouped[customer]?[project] ?? 0, 7200, accuracy: 0.001)
    }

    func testReportTypesMatchPreviousSelectionAndTotals() {
        let records = Array(report.timesheets.prefix(100))
        for type in [ReportType.day, .week, .month, .year] {
            let result = viewModel.reportResult(records: records, date: selectedDate, project: nil, type: type)
            let expected = records.filter { record in
                guard let begin = record.getBeginDate() else { return false }
                switch type {
                case .day: return begin.isDay(of: selectedDate)
                case .week: return begin.isInMondayWeek(of: selectedDate)
                case .month: return begin.isMonth(of: selectedDate)
                case .year: return begin.isYear(of: selectedDate)
                }
            }
            XCTAssertEqual(result.timesheets, expected)
            XCTAssertEqual(result.totalDuration, KimaiTimesheet.totalHours(of: expected), accuracy: 0.001)
            XCTAssertEqual(result.totalRate, expected.reduce(0) { $0 + $1.rate }, accuracy: 0.001)
            if type != .day {
                XCTAssertEqual(result.chartBuckets.reduce(0) { $0 + $1.hours }, result.totalDuration / 3600, accuracy: 0.001)
            }
        }
    }

    func testInitialDatePreparationPerformance() {
        let records = report.timesheets
        measure(metrics: [XCTClockMetric()]) {
            preparedChart = ReportViewModel().prepareTimesheets(records)
        }
    }

    func testInitialReportPreparationPerformance() {
        measure(metrics: [XCTClockMetric()]) {
            preparedChart = report.reportResult(using: ReportViewModel())
        }
    }

    func testCachedReportPreparationPerformance() {
        _ = report.reportResult(using: viewModel)
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<100 {
                preparedChart = report.getReportChart(result: report.reportResult(using: viewModel))
            }
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
            preparedChart = report.getReportChart(result: report.reportResult(using: viewModel))
        }
    }
}
