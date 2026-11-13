import SwiftUI
import Redux
import Dependencies
import CommonUI

struct ReportContainer: View {
    @Dependency(\.router) var router
    @ObservedObject var store: ViewStoreOf<ReportComponent>
    var route: ReportComponent.Route
    
    public var body: some View {
        switch(route) {
        case .reports:
            ReportsView(
                timesheets: store.state.timesheets,
                timesheetChanges: store.state.timesheetsChanges,
                projects: store.state.projects,
                activities: store.state.activities,
                customers: store.state.customers,
                selectedCustomer: store.state.selectedCustomer,
                selectedTeam: store.state.selectedTeam,
                
                selectedProject: store.binding(for: \.selectedProject, action: ReportComponent.Action.projectSelected),
                selectedDate: store.binding(for: \.selectedDate, action: ReportComponent.Action.dateSelected),
                selectedReportType: store.binding(for: \.selectedReportType, action: ReportComponent.Action.reportTypeSelected),
                
                editTapped: { router.showSheet(.management(.kimai(.timesheetSheet($0)))) },
                deleteTapped: { store.send(.reports(.deleteTapped($0))) }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    let count = [store.state.selectedCustomer, store.state.selectedProject, store.state.selectedTeam].compactMap { $0 }.count
                    HStack(spacing: 0) {
                        Button { router.showSheet(.report(.filter)) } label: {
                            Image(systemName: "slider.horizontal.3")
                                .overlay(alignment: .topTrailing) {
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.themeForeground)
                                            .padding(3)
                                            .background(Color.theme, in: Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }
                        .accessibilityLabel("Berichte filtern, \(count) aktiv")
                        Button { router.showSheet(.management(.kimai(.timesheetSheet(.new)))) } label: {
                            Image(systemName: "play.fill")
                        }
                        .accessibilityLabel("Zeiteintrag erstellen")
                    }
                    .buttonStyle(IconButtonStyle())
                    .foregroundStyle(Color.theme)
                }
            }
        case .calendar:
            ReportCalendarView(
                months: store.state.months,
                selectedDate: store.state.selectedDate,
                lastYearTapped: { store.send(.calendar(.previousYearTapped)) },
                nextYearTapped: { store.send(.calendar(.nextYearTapped)) },
                monthTapped: { store.send(.calendar(.monthTapped($0))) }
            )
        case .filter:
            ReportFilterView(
                customers: store.state.customers,
                projects: store.state.projects,
                teams: store.state.teams,
                customer: store.state.selectedCustomer,
                project: store.state.selectedProject,
                team: store.state.selectedTeam,
                apply: { customer, project, team in
                    store.send(.filtersSelected(customer: customer, project: project, team: team))
                }
            )
        case .filterProjects:
            ReportFilterProjectsView(
                customers: store.state.customers,
                projects: store.state.projects,
                selectedProject: store.state.selectedProject,
                allProjectsTapped: { store.send(.filterProjects(.allProjectsTapped)) },
                projectTapped: {
                    router.dismiss()
                    store.send(.filterProjects(.projectTapped($0)))
                }
            )
        }
        
    }
    
    
}
