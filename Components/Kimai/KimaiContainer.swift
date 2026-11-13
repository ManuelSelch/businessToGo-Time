import SwiftUI
import Dependencies
import Redux

import CommonUI
import KimaiUI
import KimaiCore
import OfflineSyncCore

struct KimaiContainer: View {
    @Dependency(\.router) var router
    @ObservedObject var store: ViewStoreOf<KimaiComponent>
    let route: KimaiComponent.Route
    
    var body: some View {
        VStack {
            switch(route) {
            case .customersList:
                KimaiCustomersListView(
                    customers: store.state.customers.filter { customer in
                        let projects = store.state.projects.filter { $0.customer == customer.id }.map(\.name)
                        return CustomerSearch.includes(name: customer.name, projectNames: projects, teams: customer.teams, selectedTeam: store.state.selectedTeam, query: store.state.customerSearch)
                    },
                    projects: store.state.projects,
                    search: store.binding(for: \.customerSearch, action: { .searchChanged($0) }),
                    hasFilters: store.state.selectedTeam != nil || !store.state.customerSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    resetFilters: { store.send(.teamSelected(nil)); store.send(.searchChanged("")) },
                    
                    customerEditTapped: { router.showSheet(.management(.kimai(.customerSheet($0)))) },
                    customerDeleteTapped: { store.send(.customer(.deleteTapped($0))) },
                    customerCreated: { router.showSheet(.management(.kimai(.customerSheet(.new)))) },
                    projectTapped: { router.push(.management(.kimai(.projectDetail($0.id)))) },
                    projectEditTapped: { router.showSheet(.management(.kimai(.projectSheet($0)))) },
                    projectDeleteTapped: { store.send(.project(.deleteTapped($0))) },
                    projectCreated: { customer in
                        var project = KimaiProject.new
                        project.customer = customer.id
                        router.showSheet(.management(.kimai(.projectSheet(project))))
                    }
                )
            case let .customerSheet(customer):
                KimaiCustomerSheet(
                    customer: customer,
                    teams: store.state.teams,
                    saveTapped: { customer in
                        router.dismiss()
                        store.send(.customer(.saveTapped(customer)))
                        if customer.id == KimaiCustomer.new.id {
                            store.send(.teamSelected(nil))
                            store.send(.searchChanged(""))
                        }
                    },
                    cancelTapped: { router.dismiss() }
                )
                
            case let .projectsList(customer):
                KimaiProjectsListView(
                    customer: customer,
                    projects: store.state.projects,
                    timesheets: store.state.timesheets,
                    
                    projectTapped: { router.push(.management(.kimai(.projectDetail($0)))) },
                    projectEditTapped: { router.showSheet(.management(.kimai(.projectSheet($0)))) },
                    projectDeleteTapped: { store.send(.project(.deleteTapped($0))) },
                    projectCreated: { store.send(.project(.created($0))) }
                )
            case let .projectSheet(project):
                KimaiProjectSheet(
                    project: project,
                    customers: store.state.customers,
                    saveTapped: { router.dismiss(); store.send(.project(.saveTapped($0))) }
                )
            case let .projectDetail(id):
                if let project = store.state.projects.get(id) {
                    KimaiProjectDetailsView(
                        project: project,
                        customer: store.state.customers.first { $0.id == project.customer },
                        timesheets: store.state.timesheets,
                        activities: store.state.activities,
                        users: store.state.users,
                        
                        timesheetEditTapped: { router.showSheet(.management(.kimai(.timesheetSheet($0)))) },
                        timesheetDeleteTapped: { store.send(.timesheet(.deleteTapped($0))) },
                        
                        
                        activityEditTapped: { router.showSheet(.management(.kimai(.activitySheet($0)))) },
                        activityDeleteTapped: { store.send(.activity(.deleteTapped($0))) },
                        activityCreated: { store.send(.activity(.created($0))) }
                    )
                } else {
                    Text("project not found")
                }
                
            case let .activitySheet(activity):
                KimaiActivitySheet(
                    activity: activity,
                    projects: store.state.projects,
                    saveTapped: { router.dismiss(); store.send(.activity(.saveTapped($0))) }
                )
                
            case let .timesheetSheet(timesheet):
                KimaiTimesheetSheet(
                    timesheet: timesheet,
                    customers: store.state.customers,
                    projects: store.state.projects,
                    activities: store.state.activities,
                    saveTapped: { router.dismiss();store.send(.timesheet(.saveTapped($0))) }
                )
                
            case let .popup(route):
                switch(route) {
                case .customerDeleteNotAllowed:
                    PopupView(
                        title: "Customer delete not allowed",
                        message: "Remove linked projects",
                        
                        okayTapped: {},
                        cancelTapped: { store.send(.popupCloseTapped) }
                    )
                case .customerDeleteConfirmation(let customer):
                    PopupView(
                        title: "Customer delete",
                        message: "Are you sure?",
                        
                        okayTapped: { store.send(.customer(.deleteConfirmed(customer))) },
                        cancelTapped: { store.send(.popupCloseTapped) }
                    )
                    
                case .projectDeleteNotAllowed(_):
                    PopupView(
                        title: "Project delete not allowed",
                        message: "Remove linked timesheets",
                        
                        okayTapped: {},
                        cancelTapped: { store.send(.popupCloseTapped) }
                    )
                case .projectDeleteConfirmation(let project):
                    PopupView(
                        title: "Project delete",
                        message: "Are you sure?",
                        
                        okayTapped: { store.send(.project(.deleteConfirmed(project))) },
                        cancelTapped: { store.send(.popupCloseTapped) }
                    )
                    
                case .activityDeleteConfirmation(let activity):
                    PopupView(
                        title: "Activity delete",
                        message: "Are you sure?",
                        
                        okayTapped: { store.send(.activity(.deleteConfirmed(activity))) },
                        cancelTapped: { store.send(.popupCloseTapped) }
                    )
                    
                case .timesheetDeleteConfirmation(let timesheet):
                    PopupView(
                        title: "Timesheet delete",
                        message: "Are you sure?",
                        
                        okayTapped: { store.send(.timesheet(.deleteConfirmed(timesheet))) },
                        cancelTapped: { store.send(.popupCloseTapped) }
                    )
                }
            }
        }
        .frame(maxWidth: 1000)
    }
}
