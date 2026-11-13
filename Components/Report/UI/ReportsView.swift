import SwiftUI
import Charts
import OfflineSyncCore
import MyChart

import CommonCore
import CommonUI
import KimaiCore
import KimaiUI

class ReportViewModel: ObservableObject {
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
    var timesheetsFiltered: [KimaiTimesheet] {
        var timesheets = timesheets
        
        if let project = selectedProject {
            timesheets = timesheets.filter { $0.project == project }
        }
        
        switch(selectedReportType){
        case .day:
            return timesheets.filter{ $0.getBeginDate()?.isDay(of: selectedDate) ?? false }
        case .week:
            return timesheets.filter { $0.getBeginDate()?.isInMondayWeek(of: selectedDate) ?? false }
        case .month:
            return timesheets.filter { $0.getBeginDate()?.isMonth(of: selectedDate) ?? false }
        case .year:
            return timesheets.filter { $0.getBeginDate()?.isYear(of: selectedDate) ?? false }
        }
    }
    
    
    var body: some View {
        VStack(spacing: 0){
            getHeader()
            getReportChart()
            getBody()
        }
        .scrollContentBackground(.hidden)
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
    func getBody() -> some View {
        switch(selectedReportType) {
        case .day:
            getTimesheets()
        case .week:
            getTimesheets()
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
    func getTimesheets() -> some View {
       
        if selectedReportType == .week && timesheetsFiltered.isEmpty {
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
                timesheets: timesheetsFiltered,
                activities: activities,
                timesheetChanges: timesheetChanges,
                deleteTapped: deleteTapped,
                editTapped: editTapped
            )
        }
         
    }
    
    @ViewBuilder
    func getReportChart() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportSummaryView(timesheets: timesheetsFiltered)

            switch selectedReportType {
            case .week:
                reportBarChart(period: .week)
            case .month:
                reportBarChart(period: .month)
            case .year:
                reportBarChart(period: .year)
            case .day:
                ChartPieView(customers.map { .init(id: $0.id, name: $0.name, value: 10) })
                    .chartLegend(.hidden)
                    .frame(height: 100)
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

extension ReportsView {
    private func reportBarChart(period: ReportChartPeriod) -> some View {
        let entries = timesheetsFiltered.compactMap { timesheet -> ReportChartEntry? in
            guard let date = timesheet.getBeginDate() else { return nil }
            return ReportChartEntry(date: date, hours: (timesheet.calculateDuration() ?? 0) / 3600)
        }
        return ReportBarChart(buckets: ReportChartData.buckets(period: period, selectedDate: selectedDate, entries: entries))
    }
}
