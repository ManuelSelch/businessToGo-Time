import Foundation
import Combine
import Moya
import OfflineSyncServices
import OfflineSyncCore
import KimaiCore
import Redux
import ReduxDebug
import KimaiServices

public extension KimaiFeature {
    func fetchOffline(_ state: inout State) {
        do {
            var next = state
            next.customers = try kimai.customers.getCustomers().filter { $0.visible }
            next.projects = try kimai.projects.get().filter { $0.visible }
            next.activities = try kimai.activities.get().filter { $0.visible }
            next.teams = try kimai.customers.getTeams()
            next.users = try kimai.users.get()
            next.timesheets = try kimai.timesheets.get()
            try getChanges(&next)
            state = next
        } catch {
            state.syncStatus = .failed
            Logger.error("failed reading local kimai data")
        }
    }

    func getChanges(_ state: inout State) throws {
        state.customerChanges = try kimai.customers.getCustomerChanges()
        state.projectChanges = try kimai.projects.getChanges()
        state.activityChanges = try kimai.activities.getChanges()
        state.timesheetChanges = try kimai.timesheets.getChanges()
    }

    func delete<Table: KimaiTableProtocol>(_ record: Table, service: RecordService<Table>) throws -> [Table] {
        guard var record = try service.getRecord(record.id) else { throw ServiceError.recordMissing }
        let changes = try service.getChanges()
        if changes.get(record.id)?.type == .insert {
            try service.delete(record.id)
        } else {
            record.visible = false
            try service.update(record)
        }
        return try service.get().filter { $0.visible }
    }

    func delete(_ record: KimaiCustomer, service: KimaiCustomerService) throws -> [KimaiCustomer] {
        guard var record = try service.getCustomer(record.id) else { throw ServiceError.recordMissing }
        let changes = try service.getCustomerChanges()
        if changes.get(record.id)?.type == .insert {
            try service.deleteCustomer(record.id)
        } else {
            record.visible = false
            try service.updateCustomer(record)
        }
        return try service.getCustomers().filter { $0.visible }
    }

    func reduce(_ state: inout State, _ action: Action) -> Effect<Action> {
        do {
            switch action {
            case let .customer(action):
                switch action {
                case let .teamSelected(team): state.selectedTeam = team
                case let .searchChanged(query): state.customerSearch = query
                case let .save(customer):
                    try kimai.save(customer)
                    state.customers = try kimai.customers.getCustomers().filter { $0.visible }
                    try getChanges(&state)
                case let .delete(customer):
                    guard !state.projects.contains(where: { $0.customer == customer.id }) else {
                        return .send(.delegate(.popup(.customerDeleteNotAllowed(customer))))
                    }
                    return .send(.delegate(.popup(.customerDeleteConfirmation(customer))))
                case let .deleteConfirmed(customer):
                    state.customers = try delete(customer, service: kimai.customers)
                    try getChanges(&state)
                    return .send(.delegate(.dismissPopup))
                }
            case let .project(action):
                switch action {
                case let .save(project):
                    try kimai.save(project)
                    state.projects = try kimai.projects.get().filter { $0.visible }
                    try getChanges(&state)
                case let .delete(project):
                    guard !state.activities.contains(where: { $0.project == project.id }) else {
                        return .send(.delegate(.popup(.projectDeleteNotAllowed(project))))
                    }
                    return .send(.delegate(.popup(.projectDeleteConfirmation(project))))
                case let .deleteConfirmed(project):
                    state.projects = try delete(project, service: kimai.projects)
                    try getChanges(&state)
                    return .send(.delegate(.dismissPopup))
                }
            case let .activity(action):
                switch action {
                case let .save(activity):
                    try kimai.save(activity)
                    state.activities = try kimai.activities.get().filter { $0.visible }
                    try getChanges(&state)
                case let .delete(activity):
                    return .send(.delegate(.popup(.activityDeleteConfirmation(activity))))
                case let .deleteConfirmed(activity):
                    state.activities = try delete(activity, service: kimai.activities)
                    try getChanges(&state)
                    return .send(.delegate(.dismissPopup))
                }
            case let .timesheet(action):
                switch action {
                case let .save(timesheet):
                    try kimai.save(timesheet)
                    state.timesheets = try kimai.timesheets.get()
                    try getChanges(&state)
                case let .delete(timesheet):
                    return .send(.delegate(.popup(.timesheetDeleteConfirmation(timesheet))))
                case let .deleteConfirmed(timesheet):
                    try kimai.timesheets.delete(timesheet.id)
                    state.timesheets = try kimai.timesheets.get()
                    try getChanges(&state)
                    return .send(.delegate(.dismissPopup))
                }
            case .sync:
                guard state.syncID == nil else { return .none }
                let id = UUID()
                state.syncID = id
                state.syncStatus = .syncing
                fetchOffline(&state)
                let operation = kimai.makeSyncOperation()
                return .run { send in
                    do {
                        try await operation()
                        send(.success(.syncFinished(id, true)))
                    } catch {
                        Logger.error("failed syncing kimai")
                        send(.success(.syncFinished(id, false)))
                    }
                }
            case let .syncFinished(id, success):
                guard state.syncID == id else { return .none }
                state.syncID = nil
                // Reload current records, not an older network snapshot over a newer edit.
                fetchOffline(&state)
                if !success { state.syncStatus = .failed }
                else if state.syncStatus != .failed { state.syncStatus = .idle }
            case .delegate: return .none
            }
        } catch {
            state.syncStatus = .failed
            Logger.error("failed saving local kimai data")
        }
        return .none
    }
}
