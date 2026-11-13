import SwiftUI
import Charts
import OfflineSyncCore
import MyChart

import CommonCore
import CommonUI
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
    let chartBuckets: [ReportChartBucket]
    let hasRunningEntries: Bool
}

private struct ReportSelection: Equatable {
    let date: Date
    let project: Int?
    let allowedProjects: Set<Int>?
    let type: ReportType
    let calendar: Calendar
}

private struct CachedReport {
    let selection: ReportSelection
    let timesheets: [KimaiTimesheet]
    let totalDuration: TimeInterval
    let totalRate: Double
    let weekdayDurations: [TimeInterval]
    let chartBuckets: [ReportChartBucket]
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

    func reportResult(records: [KimaiTimesheet], date: Date, project: Int?, type: ReportType, now: Date = .now, customer: Int? = nil, team: Int? = nil, projects: [KimaiProject] = [], customers: [KimaiCustomer] = []) -> ReportResult {
        let prepared = prepareTimesheets(records)
        let allowedProjects: Set<Int>?
        if customer != nil || team != nil {
            let matchingCustomers = Set(customers.filter { item in
                if let customer, item.id != customer { return false }
                if let team, !item.teams.contains(team) { return false }
                return true
            }.map(\.id))
            allowedProjects = Set(projects.filter { matchingCustomers.contains($0.customer) }.map(\.id))
        } else {
            allowedProjects = nil
        }
        let selection = ReportSelection(date: date, project: project, allowedProjects: allowedProjects, type: type, calendar: .current)
        if cachedReport?.selection != selection {
            var selected: [KimaiTimesheet] = []
            var duration: TimeInterval = 0
            var rate: Double = 0
            var weekdays = Array(repeating: TimeInterval.zero, count: 8)
            var running: [(begin: Date, weekday: Int?)] = []
            var chartEntries: [ReportChartEntry] = []
            for entry in prepared {
                if let project = project, entry.timesheet.project != project { continue }
                if let allowedProjects = allowedProjects, !allowedProjects.contains(entry.timesheet.project) { continue }
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
                    chartEntries.append(ReportChartEntry(date: begin, hours: seconds / 3600))
                    if let weekday = weekday { weekdays[weekday] += seconds }
                } else {
                    // Missing and unparseable end dates both use the current time in calculateDuration().
                    running.append((begin, weekday))
                }
            }
            let chartPeriod: ReportChartPeriod?
            switch type {
            case .day: chartPeriod = nil
            case .week: chartPeriod = .week
            case .month: chartPeriod = .month
            case .year: chartPeriod = .year
            }
            let buckets = chartPeriod.map { ReportChartData.buckets(period: $0, selectedDate: date, entries: chartEntries) } ?? []
            cachedReport = CachedReport(selection: selection, timesheets: selected, totalDuration: duration, totalRate: rate, weekdayDurations: weekdays, chartBuckets: buckets, running: running)
        }
        let cached = cachedReport!
        var duration = cached.totalDuration
        var weekdays = cached.weekdayDurations
        for entry in cached.running {
            let seconds = now.timeIntervalSince(entry.begin)
            duration += seconds
            if let weekday = entry.weekday { weekdays[weekday] += seconds }
        }
        var buckets = cached.chartBuckets
        if !cached.running.isEmpty, !buckets.isEmpty {
            let period: ReportChartPeriod = type == .week ? .week : (type == .month ? .month : .year)
            let runningEntries = cached.running.map { ReportChartEntry(date: $0.begin, hours: now.timeIntervalSince($0.begin) / 3600) }
            let runningBuckets = ReportChartData.buckets(period: period, selectedDate: date, entries: runningEntries)
            buckets = zip(buckets, runningBuckets).map { bucket, running in
                ReportChartBucket(id: bucket.id, label: bucket.label, accessibilityLabel: bucket.accessibilityLabel, hours: bucket.hours + running.hours)
            }
        }
        return ReportResult(timesheets: cached.timesheets, totalDuration: duration, totalRate: cached.totalRate, weeklyTotals: weekdays.map { $0 / 3600 }, chartBuckets: buckets, hasRunningEntries: !cached.running.isEmpty)
    }

    func groupRecords(records: [KimaiTimesheet], projects: [KimaiProject], customers: [KimaiCustomer]) -> [KimaiCustomer: [KimaiProject: Double]] {
        var result: [KimaiCustomer: [KimaiProject: Double]] = [:]

        for record in records {
            guard let project = projects.first(where: {$0.id == record.project}) else { continue }
            guard let customer = customers.first(where: {$0.id == project.customer}) else { continue }

            result[customer, default: [:]][project,default: 0]  += record.calculateDuration() ?? 0
        }

        return result
    }
}

struct ReportsView: View {
    // MARK: - State
    let timesheets: [KimaiTimesheet]
    let timesheetChanges: [DatabaseChange]
    let projects: [KimaiProject]
    let activities: [KimaiActivity]
    let customers: [KimaiCustomer]
    var selectedCustomer: Int? = nil
    var selectedTeam: Int? = nil
    @Binding var selectedProject: Int?
    @Binding var selectedDate: Date
    @Binding var selectedReportType: ReportType
    
    // MARK: - Action
    let editTapped: (KimaiTimesheet) -> ()
    let deleteTapped: (KimaiTimesheet) -> ()
    
    @StateObject var viewModel = ReportViewModel()
    
    
    // MARK: - View
    func reportResult(using viewModel: ReportViewModel, now: Date = .now) -> ReportResult {
        viewModel.reportResult(records: timesheets, date: selectedDate, project: selectedProject, type: selectedReportType, now: now, customer: selectedCustomer, team: selectedTeam, projects: projects, customers: customers)
    }

    var body: some View {
        let result = reportResult(using: viewModel)
        return VStack(spacing: 0){
            getHeader()
            if result.hasRunningEntries {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let current = reportResult(using: viewModel, now: context.date)
                    getReportChart(result: current)
                    getBody(timesheets: current.timesheets)
                }
            } else {
                getReportChart(result: result)
                getBody(timesheets: result.timesheets)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

extension ReportsView {
    
    @ViewBuilder
    func getHeader() -> some View {
        ReportHeaderView(
            selectedReportType: $selectedReportType,
            selectedDate: $selectedDate
        )
    }
    
    @ViewBuilder
    func getBody(timesheets: [KimaiTimesheet]) -> some View {
        switch(selectedReportType) {
        case .day:
            ReportDayTimeline(timesheets: timesheets, projects: projects, customers: customers, activities: activities, timesheetChanges: timesheetChanges, edit: editTapped, delete: deleteTapped)
        case .week:
            ReportWeekEntries(timesheets: timesheets, projects: projects, customers: customers, activities: activities, timesheetChanges: timesheetChanges, edit: editTapped, delete: deleteTapped)
        case .month, .year:
            if timesheets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar").font(.title2)
                    Text("Keine Zeiteinträge für diesen Zeitraum")
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                getSummary(timesheets: timesheets)
            }
        }
    }
    
    @ViewBuilder
    func getSummary(timesheets: [KimaiTimesheet]) -> some View {
        let groupedData = viewModel.groupRecords(records: timesheets, projects: projects, customers: customers)
        return List {
            ForEach(Array(groupedData.keys), id: \.id) { customer in
                DisclosureGroup {
                    if let projects = groupedData[customer] {
                        ForEach(Array(projects.keys).sorted { $0.name < $1.name }, id: \.id) { project in
                            HStack {
                                Text(project.name)
                                Spacer()
                                Text(MyFormatter.duration(projects[project] ?? 0))
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(customer.name)
                        Spacer()
                        Text(MyFormatter.duration(groupedData[customer]?.values.reduce(0, +) ?? 0))
                    }
                }
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
        VStack(alignment: .leading, spacing: 12) {
            ReportSummaryView(timesheets: result.timesheets, cachedTotals: (result.totalDuration, result.totalRate))

            switch selectedReportType {
            case .week, .month, .year:
                ReportBarChart(buckets: result.chartBuckets)
            case .day:
                EmptyView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.homeCard, in: RoundedRectangle(cornerRadius: 15))
        .padding(.horizontal, 16)
    }
}

private struct ReportBarChart: View {
    let buckets: [ReportChartBucket]

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Zeitraum", bucket.chartKey),
                y: .value("Stunden", bucket.hours)
            )
            .cornerRadius(4)
            .foregroundStyle(Color.theme)
            .accessibilityLabel(bucket.accessibilityLabel)
            .accessibilityValue("\(bucket.hours.formatted()) Stunden")
        }
        .chartXScale(domain: buckets.map(\.chartKey))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plot = geometry[proxy.plotAreaFrame]
                ForEach(buckets) { bucket in
                    if let x = proxy.position(forX: bucket.chartKey) {
                        Text(bucket.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .position(x: plot.minX + x, y: plot.maxY + 10)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(height: 80)
        .padding(.bottom, 20)
    }
}
