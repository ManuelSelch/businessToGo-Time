import SwiftUI
import OfflineSyncCore
import MyChart

import CommonCore
import KimaiCore
import KimaiUI

struct ReportTimesheet {
    let timesheet: KimaiTimesheet
    let beginDate: Date?
}

struct ReportResult {
    let timesheets: [KimaiTimesheet]
    let totalDuration: TimeInterval
    let totalRate: Double
    let weeklyTotals: [TimeInterval]
    let hasRunningEntries: Bool
}

private struct ReportSelection: Equatable {
    let date: Date
    let project: Int?
    let type: ReportType
    let calendar: Calendar
}

private struct CachedReport {
    let selection: ReportSelection
    let timesheets: [KimaiTimesheet]
    let totalDuration: TimeInterval
    let totalRate: Double
    let weekdayDurations: [TimeInterval]
    let running: [(begin: Date, weekday: Int?)]
}

class ReportViewModel: ObservableObject {
    private var cachedReport: CachedReport?
    private var cachedTimesheets: [KimaiTimesheet]?
    private var cachedTimeZone: TimeZone?
    private var preparedTimesheets: [ReportTimesheet] = []

    func prepareTimesheets(_ timesheets: [KimaiTimesheet]) -> [ReportTimesheet] {
        let timeZone = TimeZone.current
        if cachedTimesheets != timesheets || cachedTimeZone != timeZone {
            cachedReport = nil
            preparedTimesheets = timesheets.map { ReportTimesheet(timesheet: $0, beginDate: $0.getBeginDate()) }
            cachedTimesheets = timesheets
            cachedTimeZone = timeZone
        }
        return preparedTimesheets
    }

    func reportResult(records: [KimaiTimesheet], date: Date, project: Int?, type: ReportType, now: Date = .now) -> ReportResult {
        let prepared = prepareTimesheets(records)
        let selection = ReportSelection(date: date, project: project, type: type, calendar: .current)
        if cachedReport?.selection != selection {
            var selected: [KimaiTimesheet] = []
            var duration: TimeInterval = 0
            var rate: Double = 0
            var weekdays = Array(repeating: TimeInterval.zero, count: 8)
            var running: [(begin: Date, weekday: Int?)] = []
            for entry in prepared {
                if let project = project, entry.timesheet.project != project { continue }
                guard let begin = entry.beginDate else { continue }
                let matches: Bool
                switch type {
                case .day: matches = begin.isDay(of: date)
                case .week: matches = begin.isInMondayWeek(of: date)
                case .month: matches = begin.isMonth(of: date)
                case .year: matches = begin.isYear(of: date)
                }
                if !matches { continue }
                selected.append(entry.timesheet)
                rate += entry.timesheet.rate
                let weekday = begin.getWeekday().flatMap { (1...7).contains($0) ? $0 : nil }
                if let end = entry.timesheet.getEndDate() {
                    let seconds = end.timeIntervalSince(begin)
                    duration += seconds
                    if let weekday = weekday { weekdays[weekday] += seconds }
                } else {
                    // Missing and unparseable end dates both use the current time in calculateDuration().
                    running.append((begin, weekday))
                }
            }
            cachedReport = CachedReport(selection: selection, timesheets: selected, totalDuration: duration, totalRate: rate, weekdayDurations: weekdays, running: running)
        }
        let cached = cachedReport!
        var duration = cached.totalDuration
        var weekdays = cached.weekdayDurations
        for entry in cached.running {
            let seconds = now.timeIntervalSince(entry.begin)
            duration += seconds
            if let weekday = entry.weekday { weekdays[weekday] += seconds }
        }
        return ReportResult(timesheets: cached.timesheets, totalDuration: duration, totalRate: cached.totalRate, weeklyTotals: weekdays.map { $0 / 3600 }, hasRunningEntries: !cached.running.isEmpty)
    }

    @Published var groupedData: [KimaiCustomer: [KimaiProject: Double]] = [:] // Customer -> Project -> Total Hours

    func processRecords(records: [KimaiTimesheet], projects: [KimaiProject], customers: [KimaiCustomer]) {
        var result: [KimaiCustomer: [KimaiProject: Double]] = [:]

        for record in records {
            guard let project = projects.first(where: {$0.id == record.project}) else { continue }
            guard let customer = customers.first(where: {$0.id == project.customer}) else { continue }

            result[customer, default: [:]][project,default: 0]  += record.calculateDuration() ?? 0
        }

        DispatchQueue.main.async {
            self.groupedData = result
        }
    }
}

struct ReportsView: View {
    // MARK: - State
    let timesheets: [KimaiTimesheet]
    let timesheetChanges: [DatabaseChange]
    let projects: [KimaiProject]
    let activities: [KimaiActivity]
    let customers: [KimaiCustomer]
    @Binding var selectedProject: Int?
    @Binding var selectedDate: Date
    @Binding var selectedReportType: ReportType
    
    // MARK: - Action
    let calendarTapped: () -> ()
    let filterTapped: () -> ()
    let playTapped: () -> ()
    let editTapped: (KimaiTimesheet) -> ()
    let deleteTapped: (KimaiTimesheet) -> ()
    
    @StateObject var viewModel = ReportViewModel()
    
    
    // MARK: - View
    func reportResult(using viewModel: ReportViewModel, now: Date = .now) -> ReportResult {
        viewModel.reportResult(records: timesheets, date: selectedDate, project: selectedProject, type: selectedReportType, now: now)
    }

    var body: some View {
        let result = reportResult(using: viewModel)
        return VStack(spacing: 0){
            getHeader()
            if result.hasRunningEntries {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    getReportChart(result: reportResult(using: viewModel, now: context.date))
                }
                .frame(maxHeight: 100)
            } else {
                getReportChart(result: result)
                    .frame(maxHeight: 100)
            }
            getBody(timesheets: result.timesheets)
        }
        .onAppear {
            viewModel.processRecords(records: timesheets, projects: projects, customers: customers)
        }
    }
}

extension ReportsView {
    
    @ViewBuilder
    func getHeader() -> some View {
        ReportHeaderView(
            selectedReportType: $selectedReportType,
            selectedDate: $selectedDate ,
            selectedProject: $selectedProject,
            projects: projects,
            
            calendarTapped: calendarTapped,
            filterTapped: filterTapped,
            playTapped: playTapped
            
        )
    }
    
    @ViewBuilder
    func getBody(timesheets: [KimaiTimesheet]) -> some View {
        switch(selectedReportType) {
        case .day:
            getTimesheets(timesheets: timesheets)
        case .week:
            getTimesheets(timesheets: timesheets)
        case .month:
            getSummary()
        case .year:
            getSummary()
        }
    }
    
    @ViewBuilder
    func getSummary() -> some View {
        List {
            ForEach(Array(viewModel.groupedData.keys), id: \.id) { customer in
                Section(
                    content: {
                        if let projects = viewModel.groupedData[customer] {
                            ForEach(Array(projects.keys), id: \.id) { project in
                                HStack {
                                    Text(project.name)
                                    Spacer()
                                    
                                    Text(
                                        MyFormatter.duration(projects[project] ?? 0.0)
                                    )
                                      
                                }
                            }
                        } else {
                            Text("No projects available.")
                        }
                    },
                    header: {
                        HStack {
                            Text(customer.name)
                            Spacer()
                            Text("00:00")
                        }
                        .font(.system(size: 15))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.textHeaderSecondary)
                    }
                )
                .listRowBackground(Color.clear)
            }
        }


    }
    
    
    @ViewBuilder
    func getTimesheets(timesheets: [KimaiTimesheet]) -> some View {
       
        if selectedReportType == .week && timesheets.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.title2)
                Text("Keine Zeiteinträge für diese Woche")
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            KimaiTimesheetsListView(
                projects: projects,
                timesheets: timesheets,
                activities: activities,
                timesheetChanges: timesheetChanges,
                deleteTapped: deleteTapped,
                editTapped: editTapped
            )
        }
         
    }
    
    @ViewBuilder
    func getReportChart(result: ReportResult) -> some View {
        ReportSummaryView(timesheets: result.timesheets, cachedTotals: (result.totalDuration, result.totalRate))
        
        switch(selectedReportType){
        case .week:
            let totals = result.weeklyTotals
            ChartBarView([
                .init(id: 0, name: "Mo", value: totals[2]),
                .init(id: 1, name: "Di", value: totals[3]),
                .init(id: 2, name: "Mi", value: totals[4]),
                .init(id: 3, name: "Do", value: totals[5]),
                .init(id: 4, name: "Fr", value: totals[6]),
                .init(id: 5, name: "Sa", value: totals[7]),
                .init(id: 6, name: "So", value: totals[1])
            ], Color.theme)
        default:
            ChartPieView(customers.map { .init(id: $0.id, name: $0.name, value: 10) })
                .chartLegend(.hidden)
        }
    }
}
