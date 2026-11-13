import Foundation
import Redux

import KimaiCore
import OfflineSyncCore

struct TodayComponent: ViewModel {
    typealias DState = AppFeature.State
    typealias DAction = AppFeature.Action
    
    struct State: ViewState {
        var customers: [KimaiCustomer]
        var projects: [KimaiProject]
        var activities: [KimaiActivity]
        var timesheets: [KimaiTimesheet]
        var syncStatus: SyncStatus
        
        static func from(_ state: AppFeature.State) -> State {
            return State(
                customers: state.kimai.customers,
                projects: state.kimai.projects,
                activities: state.kimai.activities,
                timesheets: state.kimai.timesheets,
                syncStatus: state.kimai.syncStatus
            )
        }
    }
    
    enum Action: ViewAction {
        case timesheetSaveTapped(KimaiTimesheet)
        case stopTapped(KimaiTimesheet)
        case sync
        
        var lifted: AppFeature.Action {
            switch self {
            case let .timesheetSaveTapped(timesheet): return .kimai(.timesheet(.save(timesheet)))
            case .sync: return .sync
            case var .stopTapped(timesheet):
                timesheet.end = ISO8601DateFormatter().string(from: Date())
                return .kimai(.timesheet(.save(timesheet)))
            }
        }
    }
    
    enum Route: Equatable, Codable, Hashable {
        case today
        case projects(for: Int)
        case timesheet(for: Int)
    }
    
    enum UIAction: Equatable, Codable {
        case customerTapped(Int)
        case projectTapped(Int)
        case timesheetSaveTapped(KimaiTimesheet)
    }
}
