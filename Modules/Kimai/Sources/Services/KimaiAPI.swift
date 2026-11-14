import Foundation
import Moya

import KimaiCore

public enum KimaiAPI {
    case getCustomers
    case insertCustomer(KimaiCustomerDTO)
    case updateCustomer(KimaiCustomerDTO)
    
    case getProjects
    case insertProject(KimaiProject)
    case updateProject(KimaiProject)
    
    case getActivities
    case insertActivity(KimaiActivity)
    case updateActivity(KimaiActivity)
    
    case getTimesheets(_ page: Int, modifiedAfter: String? = nil)
    case getTimesheet(Int)
    case insertTimesheet(KimaiTimesheet)
    case updateTimesheet(KimaiTimesheet)
    case deleteTimesheet(Int)
    
    case getTeams
    case getUsers
    case getMe
    
}
 
extension KimaiAPI: Moya.TargetType {
    public var task: Moya.Task {
        switch self {
        case .getCustomers, .getProjects, .getActivities, .getTimesheet, .deleteTimesheet(_), .getTeams, .getUsers, .getMe:
            return .requestPlain
        case .getTimesheets:
            return .requestParameters(parameters: parameters, encoding: URLEncoding.queryString)
        default:
            return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
        }
    }
    

    public var headers: [String : String]? {
        return [
            "Content-Type": "application/json; charset=utf-8"
        ]
    }
    
    
    public var baseURL: URL {
        return KimaiAPI.server
    }
    
    public var path: String {
        switch self {
        case .getCustomers, .insertCustomer(_):
            return "/customers"
        case .updateCustomer(let customer):
            return "/customers/\(customer.id)"
            
        case .getProjects, .insertProject(_):
            return "/projects"
        case .updateProject(let project):
            return "/projects/\(project.id)"
            
        case .getTimesheets, .insertTimesheet(_):
            return "/timesheets"
        case .getTimesheet(let id):
            return "/timesheets/\(id)"
        case .updateTimesheet(let timesheet):
            return "/timesheets/\(timesheet.id)"
        case .deleteTimesheet(let id):
            return "/timesheets/\(id)"
            
        case .getActivities, .insertActivity(_):
            return "/activities"
        case .updateActivity(let activity):
            return "/activities/\(activity.id)"
            
        case .getTeams:
            return "/teams"
        case .getUsers:
            return "/users"
        case .getMe:
            return "/users/me"
        }
    }
    
    public var method: Moya.Method {
        switch self {
        case .getCustomers, .getProjects, .getActivities, .getTimesheets, .getTimesheet, .getTeams, .getUsers, .getMe:
            return .get
        case .insertTimesheet(_), .insertProject(_), .insertCustomer(_), .insertActivity(_):
            return .post
        case .updateTimesheet(_), .updateProject(_), .updateCustomer(_), .updateActivity(_):
            return .patch
        case .deleteTimesheet(_):
            return .delete
        }
    }
    
    var parameters: [String: Any] {
        switch self {
        case .getProjects, .getCustomers, .getActivities, .getTimesheet, .deleteTimesheet(_), .getTeams, .getUsers, .getMe:
            return [:]
        case let .getTimesheets(page, cursor):
            var result: [String: Any] = [
                "page": page,
                "size": 500,
                "orderBy": "id",
                "order": "ASC",
                "user": "all"
            ]
            if let cursor = cursor { result["modified_after"] = cursor }
            return result
        case .insertTimesheet(let timesheet), .updateTimesheet(let timesheet):
            return [
                "project": timesheet.project,
                "activity": timesheet.activity,
                "begin": timesheet.begin,
                "end": timesheet.end as Any,
                "description": timesheet.description as Any
            ]
        case .insertProject(let project), .updateProject(let project):
            return [
                "name": project.name,
                "customer": project.customer,
                "globalActivities": project.globalActivities,
                "visible": project.visible,
            ]
            
        case .insertCustomer(let customer), .updateCustomer(let customer):
            return [
                "name": customer.name,
                "number": customer.number as Any,
                "color": customer.color as Any,
                "country": "DE",
                "currency": "EUR",
                "timezone": "Europe/Berlin",
                "visible": customer.visible
            ]
            
        case .insertActivity(let activity), .updateActivity(let activity):
            return [
                "name": activity.name,
                "project": activity.project as Any,
                "color": activity.color as Any,
                "visible": activity.visible
            ]
            
        }
        
    }
    
    var parameterEncoding: ParameterEncoding {
        switch self {
        default:
            return URLEncoding.default
        }
    }
    
    
    // RequestService validates every HTTP status before decoding.
}


extension KimaiAPI {
    static let server = URL(string: "https://unconfigured.invalid/api")!
}
