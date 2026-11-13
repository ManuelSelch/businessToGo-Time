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

class ReportViewModel: ObservableObject {
    private var cachedTimesheets: [KimaiTimesheet]?
    private var cachedTimeZone: TimeZone?
    private var preparedTimesheets: [ReportTimesheet] = []

    func prepareTimesheets(_ timesheets: [KimaiTimesheet]) -> [ReportTimesheet] {
        let timeZone = TimeZone.current
        if cachedTimesheets != timesheets || cachedTimeZone != timeZone {
            preparedTimesheets = timesheets.map { ReportTimesheet(timesheet: $0, beginDate: $0.getBeginDate()) }
            cachedTimesheets = timesheets
            cachedTimeZone = timeZone
        }
        return preparedTimesheets
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
    func timesheetsFiltered(using viewModel: ReportViewModel) -> [ReportTimesheet] {
        let prepared = viewModel.prepareTimesheets(timesheets)
        return prepared.filter { entry in
            if let project = selectedProject, entry.timesheet.project != project { return false }
            guard let begin = entry.beginDate else { return false }
            switch selectedReportType {
            case .day: return begin.isDay(of: selectedDate)
            case .week: return begin.isInMondayWeek(of: selectedDate)
            case .month: return begin.isMonth(of: selectedDate)
            case .year: return begin.isYear(of: selectedDate)
            }
        }
    }
    
    
    var body: some View {
        let filtered = timesheetsFiltered(using: viewModel)
        return VStack(spacing: 0){
            getHeader()
            getReportChart(timesheets: filtered)
                .frame(maxHeight: 100)
            getBody(timesheets: filtered.map(\.timesheet))
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
    func getReportChart(timesheets: [ReportTimesheet]) -> some View {
        ReportSummaryView(timesheets: timesheets.map(\.timesheet))
        
        switch(selectedReportType){
        case .week:
            let totals = weeklyTotals(for: timesheets)
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

extension ReportsView {
    func weeklyTotals(for timesheets: [ReportTimesheet]) -> [TimeInterval] {
        var totals = Array(repeating: TimeInterval.zero, count: 8)
        for entry in timesheets {
            guard let weekday = entry.beginDate?.getWeekday(), (1...7).contains(weekday) else { continue }
            totals[weekday] += entry.timesheet.calculateDuration() ?? 0
        }
        return totals.map { $0 / 3600 }
    }
}
