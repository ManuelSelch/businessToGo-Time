import Foundation
import Moya
import Dependencies

import OfflineSyncCore
import OfflineSyncServices

import NetworkFoundation
import KimaiCore

public class KimaiService {
    public var customers: KimaiCustomerService
    public var projects: RecordService<KimaiProject>
    public var timesheets: RecordService<KimaiTimesheet>
    public var activities: RecordService<KimaiActivity>
    public var users: RecordService<KimaiUser>
    
    private var user: String = ""
    private var token: String = ""
    private var configured = false
    private let syncCoordinator = KimaiSyncCoordinator()
    @Dependency(\.database) private var database
    
    init(
        customers: KimaiCustomerService,
        projects: RecordService<KimaiProject>,
        timesheets: RecordService<KimaiTimesheet>,
        activities: RecordService<KimaiActivity>,
        users: RecordService<KimaiUser>
    ) {
        self.customers = customers
        self.projects = projects
        self.timesheets = timesheets
        self.activities = activities
        self.users = users
    }
    
    public func setAuth(username: String, password: String) {
        invalidateSync()
        self.user = username
        self.token = password
    }
    
    public func invalidateSync() {
        configured = false
        syncCoordinator.invalidate()
    }

    public func login(server: String) throws -> Bool {
        guard let url = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme, ["https", "http"].contains(scheme),
              url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { throw NetworkError.urlDecodeFailed }
        invalidateSync()
        let baseURL = url.appendingPathComponent("api")
        guard let db = database.connection else { throw ServiceError.databaseUnavailable }
        let identity = baseURL.absoluteString + "\n" + user
        try db.transaction {
            try db.execute("CREATE TABLE IF NOT EXISTS kimai_account_binding (id INTEGER PRIMARY KEY, identity TEXT NOT NULL)")
            if let existing = try db.scalar("SELECT identity FROM kimai_account_binding WHERE id = 1") as? String {
                guard existing == identity else { throw ServiceError.accountChanged }
            } else {
                try db.run("INSERT INTO kimai_account_binding (id, identity) VALUES (1, ?)", identity)
            }
        }
        // Fresh instances prevent account changes from mutating in-flight providers.
        if DependencyValues.mode == .live {
            customers = .live
            projects = KimaiProjectService.live
            activities = KimaiActivityService.live
            timesheets = KimaiTimesheetService.live
            users = KimaiUserService.live
        } else {
            customers = .mock
            projects = KimaiProjectService.mock
            activities = KimaiActivityService.mock
            timesheets = KimaiTimesheetService.mock
            users = KimaiUserService.mock
        }
        let plugin = KimaiAuthPlugin(user: user, token: token, baseURL: baseURL)
        customers.setPlugins([plugin])
        projects.setPlugins([plugin])
        activities.setPlugins([plugin])
        timesheets.setPlugins([plugin])
        users.setPlugins([plugin])
        configured = true
        return true
    }

    public func makeSyncOperation() -> () async throws -> Void {
        let customers = customers
        let projects = projects
        let activities = activities
        let users = users
        let timesheets = timesheets
        let configured = configured
        return syncCoordinator.operation { check in
            guard configured else { throw ServiceError.accountChanged }
            try check()
            _ = try await customers.sync()
            try check()
            _ = try await projects.sync()
            try check()
            _ = try await activities.sync()
            try check()
            _ = try await users.sync()
            try check()
            _ = try await timesheets.sync()
        }
    }

    public func save(_ model: any TableProtocol) throws {
        if let customer = model as? KimaiCustomer {
            if(customer.id == -1) {
                try customers.createCustomer(customer)
            } else {
                try customers.updateCustomer(customer)
            }
        } else if let project = model as? KimaiProject {
            if(project.id == -1) {
                try projects.create(project)
            } else {
                try projects.update(project)
            }
        } else if let timesheet = model as? KimaiTimesheet {
            if(timesheet.id == -1) {
                try timesheets.create(timesheet)
            } else {
                try timesheets.update(timesheet)
            }
        } else if let activity = model as? KimaiActivity {
            if(activity.id == -1) {
                try activities.create(activity)
            } else {
                try activities.update(activity)
            }
        } else if let user = model as? KimaiUser {
            if(user.id == -1) {
                try users.create(user)
            } else {
                try users.update(user)
            }
        }
    }
}

extension KimaiService {
    static var live = KimaiService(
        customers: KimaiCustomerService.live,
        projects: KimaiProjectService.live,
        timesheets: KimaiTimesheetService.live,
        activities: KimaiActivityService.live,
        users: KimaiUserService.live
    )
    
    static var mock = KimaiService(
        customers: KimaiCustomerService.mock,
        projects: KimaiProjectService.mock,
        timesheets: KimaiTimesheetService.mock,
        activities: KimaiActivityService.mock,
        users: KimaiUserService.mock
    )
}

struct KimaiAuthPlugin: PluginType {
    let user: String
    let token: String
    let baseURL: URL

    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var request = request
        let path = target.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedQuery }
        request.url = components.url
        request.setValue(user, forHTTPHeaderField: "X-AUTH-USER")
        request.setValue(token, forHTTPHeaderField: "X-AUTH-TOKEN")
        return request
    }
}

struct KimaiServiceKey: DependencyKey {
    static var liveValue = KimaiService.live
    static var mockValue = KimaiService.mock
}

public extension DependencyValues {
    var kimai: KimaiService {
        get { Self[KimaiServiceKey.self] }
        set { Self[KimaiServiceKey.self] = newValue }
    }
}

