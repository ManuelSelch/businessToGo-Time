import SwiftUI
import Redux
import Dependencies

import KimaiUI
import KimaiCore
import CommonUI

struct TodayContainer: View {
    @Dependency(\.router) var router
    var store: Store<TodayComponent.State, TodayComponent.Action>
    let route: TodayComponent.Route
    
    var body: some View {
        switch(route) {
        case .today:
            DashboardView(
                timesheets: store.state.timesheets,
                customers: store.state.customers,
                projects: store.state.projects,
                activities: store.state.activities,
                projectTapped: { project in
                    var timesheet = KimaiTimesheet.new
                    timesheet.project = project.id
                    router.showSheet(.management(.kimai(.timesheetSheet(timesheet))))
                },
                browseTapped: { router.showTab(.management, route: .management(.kimai(.customersList))) },
                createTapped: { router.showSheet(.management(.kimai(.timesheetSheet(.new)))) },
                stopTapped: { store.send(.stopTapped($0)) }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 0) {
                        Button { router.showSheet(.management(.kimai(.timesheetSheet(.new)))) } label: {
                            Image(systemName: "play.fill")
                        }
                        .accessibilityLabel("Zeiteintrag erstellen")
                        if store.state.syncStatus == .syncing {
                            ProgressView().frame(width: ControlSpacing.touchTarget, height: ControlSpacing.touchTarget)
                        } else {
                            Button { store.send(.sync) } label: {
                                Image(systemName: store.state.syncStatus == .failed ? "exclamationmark.icloud.fill" : "arrow.triangle.2.circlepath")
                            }
                            .accessibilityLabel(store.state.syncStatus == .failed ? "Synchronisierung fehlgeschlagen, erneut versuchen" : "Synchronisieren")
                        }
                        Button { router.showSheet(.settings(.settings)) } label: { Image(systemName: "gear") }
                            .accessibilityLabel("Einstellungen")
                    }
                    .buttonStyle(IconButtonStyle())
                    .foregroundStyle(Color.theme)
                }
            }
        case let .projects(for: customer):
            ProjectsView(
                projects: store.state.projects.filter({$0.customer == customer}),
                
                projectTapped: { router.push(.today(.timesheet(for: $0.id))) }
            )
       
        case let .timesheet(for: project):
            TimesheetView(
                project: project, 
                activities: store.state.activities,
                
                saveTapped: { router.dismiss(); store.send(.timesheetSaveTapped($0)) }
            )
        }
    }
}

