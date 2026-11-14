import XCTest
import Foundation
import SQLite
import Moya
import Dependencies
import OfflineSyncCore
import OfflineSyncServices
import KimaiCore
import KimaiApp
@testable import KimaiServices

private struct SyncRecord: TableProtocol {
    var id = -1
    var name = ""
    var parent = 0

    init() {}
    init(_ id: Int, _ name: String, parent: Int = 0) {
        self.id = id
        self.name = name
        self.parent = parent
    }
}

private enum FixtureFailure: Error { case fetch, upload, unexpectedNetwork }

private final class ControlledRemote: RequestServiceProtocol {
    var records: [SyncRecord] = []
    var creates: [SyncRecord] = []
    var updates: [SyncRecord] = []
    var nextID = 100
    var fetchError = false
    var failSecondUpload = false
    var onFetch: (() -> Void)?
    var onUpdate: (() throws -> Void)?

    func setPlugins(_ plugins: [PluginType]) {}

    func fetch() async throws -> [SyncRecord] {
        onFetch?()
        if fetchError { throw FixtureFailure.fetch }
        return records
    }

    func insert(_ model: SyncRecord) async throws -> SyncRecord {
        if failSecondUpload && creates.count == 1 {
            failSecondUpload = false
            throw ServiceError.httpStatus(429)
        }
        creates.append(model)
        var result = model
        result.id = nextID
        nextID += 1
        records.append(result)
        return result
    }

    func update(_ model: SyncRecord) async throws -> SyncRecord {
        updates.append(model)
        try onUpdate?()
        records.removeAll { $0.id == model.id }
        records.append(model)
        return model
    }

    func delete(_ id: Int) async throws {
        records.removeAll { $0.id == id }
    }
}

private final class RelatedRemote<Model: TableProtocol>: RequestServiceProtocol {
    var uploads: [Model] = []
    var records: [Model] = []
    var onFetch: (() async throws -> Void)?
    var onInsert: (() -> Void)?
    let serverID: Int

    init(serverID: Int) { self.serverID = serverID }
    func setPlugins(_ plugins: [PluginType]) {}
    func fetch() async throws -> [Model] {
        try await onFetch?()
        return records
    }
    func insert(_ model: Model) async throws -> Model {
        onInsert?()
        uploads.append(model)
        var result = model
        result.id = serverID
        return result
    }
    func update(_ model: Model) async throws -> Model { throw FixtureFailure.unexpectedNetwork }
    func delete(_ id: Int) async throws { throw FixtureFailure.unexpectedNetwork }
}

private actor ReferenceFetchGate {
    private var released = false
    private var waiters: [String: CheckedContinuation<Void, Error>] = [:]
    private var failed: Set<String> = []
    private(set) var cancelled: Set<String> = []
    private(set) var maximum = 0

    func wait(_ name: String, started: XCTestExpectation) async throws {
        try await withTaskCancellationHandler(operation: {
            try _Concurrency.Task.checkCancellation()
            if failed.contains(name) { throw FixtureFailure.fetch }
            if released { return }
            try await withCheckedThrowingContinuation { continuation in
                waiters[name] = continuation
                maximum = max(maximum, waiters.count)
                started.fulfill()
            }
        }, onCancel: { _Concurrency.Task { await self.cancel(name) } })
    }

    private func cancel(_ name: String) {
        cancelled.insert(name)
        waiters.removeValue(forKey: name)?.resume(throwing: CancellationError())
    }

    func fail(_ name: String) {
        failed.insert(name)
        waiters.removeValue(forKey: name)?.resume(throwing: FixtureFailure.fetch)
    }

    func release() {
        released = true
        for continuation in waiters.values { continuation.resume() }
        waiters = [:]
    }
}

private final class UploadOrderProbe {
    private let lock = NSLock()
    private var entries: [String] = []
    func record(_ name: String) { lock.lock(); entries.append(name); lock.unlock() }
    var names: [String] { lock.lock(); defer { lock.unlock() }; return entries }
}

private actor SyncGate {
    private var open = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { continuations.append($0) }
    }
    func release() {
        open = true
        for continuation in continuations { continuation.resume() }
        continuations = []
    }
}

private final class PageConcurrencyProbe: PluginType {
    private let lock = NSLock()
    private var active = 0
    private(set) var maximum = 0
    func willSend(_ request: RequestType, target: TargetType) {
        lock.lock()
        active += 1
        maximum = max(maximum, active)
        lock.unlock()
    }
    func didReceive(_ result: Swift.Result<Moya.Response, MoyaError>, target: TargetType) {
        lock.lock()
        active -= 1
        lock.unlock()
    }
}

private enum PageAPI: TargetType {
    case page(Int)
    var baseURL: URL { URL(string: "https://sync-fixture.invalid")! }
    var path: String { "/records" }
    var method: Moya.Method { .get }
    var task: Moya.Task { .requestPlain }
    var headers: [String: String]? { nil }
}

// Owns all storage, global DI restoration, controlled transport and assertions.
// No production account, Keychain, server, Database.live or reset adapter is used.
final class SyncRegressionDriver {
    private let directory: URL
    private var connections: [String: Connection]
    private var account = "a"
    private let previousMode: DependencyValues.Mode
    private let previousDatabase: Database
    private let previousTrack: TrackTable
    private let remote = ControlledRemote()
    private var repository: DatabaseRepository<SyncRecord>!
    private var service: RecordService<SyncRecord>!
    private var customerService: KimaiCustomerService?
    private var customerRemote: RelatedRemote<KimaiCustomerDTO>?
    private let referenceUploads = UploadOrderProbe()
    private var projectService: RecordService<KimaiProject>?
    private var projectRepository: DatabaseRepository<KimaiProject>?
    private var projectRemote: RelatedRemote<KimaiProject>?
    private var preSyncProject: KimaiProject?
    private var localCustomerID: Int?
    private var activityService: RecordService<KimaiActivity>?
    private var timesheetService: RecordService<KimaiTimesheet>?
    private var activityRemote: RelatedRemote<KimaiActivity>?
    private var timesheetRemote: RelatedRemote<KimaiTimesheet>?
    private var activityRepository: DatabaseRepository<KimaiActivity>?
    private var timesheetRepository: DatabaseRepository<KimaiTimesheet>?
    private var pages: [Int] = []
    private let pagesLock = NSLock()
    private var pageProbe: PageConcurrencyProbe?
    private var incremental: TimesheetSyncService?
    private var incrementalPages: PageRequestService<KimaiTimesheet, KimaiAPI>?
    private var requestedCheckpoints: [String?] = []
    private weak var testCase: XCTestCase?

    init(testCase: XCTestCase) throws {
        self.testCase = testCase
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("sync-regression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            connections = [
                "a": try Connection(directory.appendingPathComponent("a.sqlite").path),
                "b": try Connection(directory.appendingPathComponent("b.sqlite").path)
            ]
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        previousMode = DependencyValues.mode
        DependencyValues.mode = .mock
        previousDatabase = DependencyValues[\.database]
        previousTrack = DependencyValues[\.track]

        var database = Database.mock
        database.getConnection = { [unowned self] in self.connections[self.account] }
        database.switchDB = { [unowned self] in self.switchAccount(to: $0) }
        database.deleteDB = { _ in XCTFail("Unexpected database deletion") }
        database.deleteAllDBs = { _ in XCTFail("Unexpected global reset") }
        DependencyValues[\.database] = database
        DependencyValues[\.track] = TrackTable()
        try makeService()
    }

    func close() throws {
        service = nil
        customerService = nil
        projectService = nil
        projectRepository = nil
        activityService = nil
        timesheetService = nil
        activityRepository = nil
        timesheetRepository = nil
        incremental = nil
        incrementalPages = nil
        repository = nil
        connections.removeAll()
        DependencyValues[\.database] = previousDatabase
        DependencyValues[\.track] = previousTrack
        DependencyValues.mode = previousMode
        try FileManager.default.removeItem(at: directory)
    }

    private func makeService() throws {
        repository = DatabaseRepository("records")
        _ = try repository.get()
        service = RecordService(repository: repository, requestService: remote)
    }

    func cacheRecord(_ id: Int, named name: String) throws {
        try repository.insert(SyncRecord(id, name), isTrack: false)
        remote.records.append(SyncRecord(id, name))
    }

    func editRecord(_ id: Int, named name: String) throws { try service.update(SyncRecord(id, name)) }
    func createRecord(named name: String) throws { try service.create(SyncRecord(-1, name)) }
    func addRemoteRecord(_ id: Int, named name: String) { remote.records.append(SyncRecord(id, name)) }
    func assignNextServerID(_ id: Int) { remote.nextID = id }
    func shouldRejectCreate(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try createRecord(named: name), file: file, line: line)
    }
    func failNextFetch() { remote.fetchError = true }
    func failSecondUploadOnce() { remote.failSecondUpload = true }

    func editAgainDuringUpload(_ id: Int, named name: String) {
        remote.onUpdate = { [unowned self] in try self.editRecord(id, named: name) }
    }

    func switchAccount(to name: String) {
        precondition(connections[name] != nil)
        account = name
        // Ensure synthetic schemas exist in both accounts, just as repository.get does.

    }

    func switchToAccountDuringFetch(_ name: String) {
        remote.onFetch = { [unowned self] in self.switchAccount(to: name) }
        remote.records = [SyncRecord(1, "server A")]
    }

    func reopenCurrentAccount() throws {
        service = nil
        repository = nil
        connections[account] = nil
        connections[account] = try Connection(directory.appendingPathComponent("\(account).sqlite").path)
        try makeService()
    }

    func usePaginatedRemote(totalPages: String?, failSecondPage: Bool = false, status: Int = 200, delayed: Bool = false, empty: Bool = false) {
        let probe = PageConcurrencyProbe()
        pageProbe = probe
        let provider = MoyaProvider<PageAPI>(endpointClosure: { [unowned self] target in
            guard case let .page(page) = target else { fatalError("Unknown fixture page") }
            self.pagesLock.lock()
            self.pages.append(page)
            self.pagesLock.unlock()
            let response: EndpointSampleResponse
            if failSecondPage && page == 2 {
                response = .networkError(NSError(domain: "sync-fixture", code: 1))
            } else {
                let headers = totalPages.map { ["X-Total-Pages": $0] } ?? [:]
                let http = HTTPURLResponse(url: target.baseURL, statusCode: status, httpVersion: nil, headerFields: headers)!
                response = .response(http, try! JSONEncoder().encode(empty ? [] : [SyncRecord(page, "page \(page)")]))
            }
            return Endpoint(url: target.baseURL.appendingPathComponent(target.path).absoluteString,
                            sampleResponseClosure: { response }, method: .get, task: .requestPlain, httpHeaderFields: nil)
        }, stubClosure: { _ in delayed ? .delayed(seconds: 0.01) : .immediate }, plugins: [probe])
        let request = PageRequestService<SyncRecord, PageAPI>(fetchMethod: PageAPI.page, provider: provider,
            _setPlugins: { _ in
                XCTFail("Unexpected transport replacement")
                return provider
            })
        service = RecordService(repository: repository, requestService: request)
    }

    func useIncrementalTimesheetRemote(failThird: Bool = false, rollbackThird: Bool = false) {
        let provider = MoyaProvider<KimaiAPI>(endpointClosure: { [unowned self] target in
            guard case let .getTimesheets(page, checkpoint) = target, page == 1 else {
                XCTFail("Unexpected incremental fixture request")
                return Endpoint(url: "https://sync-fixture.invalid", sampleResponseClosure: { .networkError(NSError(domain: "fixture", code: 1)) }, method: .get, task: .requestPlain, httpHeaderFields: nil)
            }
            self.requestedCheckpoints.append(checkpoint)
            let step = self.requestedCheckpoints.count
            var old = KimaiTimesheet()
            old.id = 1
            old.begin = "2020-01-01T09:00:00+00:00"
            old.description = "old history"
            var changed = KimaiTimesheet()
            changed.id = 2
            changed.begin = "2026-11-14T09:00:00+00:00"
            changed.description = step < 3 ? "original" : "changed"
            let records = step == 1 ? [old] : (step == 2 || checkpoint == nil ? [old, changed] : [changed])
            let hour = rollbackThird && step >= 3 ? "08" : "09"
            let minute = String(format: "%02d", (step - 1) % 60)
            let date = "Sat, 14 Nov 2026 \(hour):\(minute):00 GMT"
            let http = HTTPURLResponse(url: URL(string: "https://sync-fixture.invalid")!, statusCode: failThird && step == 3 ? 503 : 200, httpVersion: nil,
                headerFields: ["X-Total-Pages": "1", "Date": date])!
            let data = try! JSONEncoder().encode(records)
            return Endpoint(url: "https://sync-fixture.invalid/timesheets", sampleResponseClosure: { .response(http, data) }, method: .get, task: .requestPlain, httpHeaderFields: nil)
        }, stubClosure: MoyaProvider.immediatelyStub)
        incrementalPages = PageRequestService(fetchMethod: { KimaiAPI.getTimesheets($0) }, provider: provider,
            _setPlugins: { _ in XCTFail("Unexpected fixture transport replacement"); return provider })
        recreateIncrementalTimesheetService()
    }

    func recreateIncrementalTimesheetService() {
        incremental = TimesheetSyncService(repository: DatabaseRepository<KimaiTimesheet>("kimai_timesheets"), pages: incrementalPages!)
    }

    func synchronizeIncrementalTimesheets() async throws { _ = try await incremental!.sync() }

    func discardFetchedTimesheetSnapshot() async throws {
        let session = try SyncSession(connection: incremental!.repository.connection())
        let state = try incremental!.prepareFetch(session: session)
        _ = try await incremental!.fetchSnapshot(state: state, session: session)
    }

    func shouldHaveNoTimesheetCheckpoint(file: StaticString = #filePath, line: UInt = #line) throws {
        let count = try connections[account]!.scalar("SELECT COUNT(*) FROM kimai_sync_checkpoint") as? Int64
        XCTAssertEqual(count, 0, file: file, line: line)
        XCTAssertTrue(try incremental!.get().isEmpty, file: file, line: line)
    }

    func repeatIncrementalSync(_ count: Int) async throws {
        for _ in 0..<count { try await synchronizeIncrementalTimesheets() }
    }

    func shouldPeriodicallyRefreshFullHistory(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(requestedCheckpoints.count, 22, file: file, line: line)
        guard requestedCheckpoints.count == 22 else { return }
        XCTAssertNil(requestedCheckpoints[21], file: file, line: line)
        XCTAssertTrue(requestedCheckpoints[2..<21].allSatisfy { $0 != nil }, file: file, line: line)
    }

    func shouldRejectIncrementalSync(file: StaticString = #filePath, line: UInt = #line) async {
        do { try await synchronizeIncrementalTimesheets(); XCTFail("Expected failed delta", file: file, line: line) } catch {}
    }

    func shouldHaveUsedIncrementalCheckpoint(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(requestedCheckpoints, [nil, nil, "2026-11-14T08:59:59"], file: file, line: line)
    }

    func shouldHaveRetriedSameCheckpoint(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(requestedCheckpoints, [nil, nil, "2026-11-14T08:59:59", "2026-11-14T08:59:59"], file: file, line: line)
    }

    func shouldHaveRefetchedAfterClockRollback(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(requestedCheckpoints, [nil, nil, "2026-11-14T08:59:59", nil], file: file, line: line)
    }

    func shouldHaveRetainedHistoryAndMergedDelta(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(try incremental?.get().first { $0.id == 1 }?.description, "old history", file: file, line: line)
        XCTAssertEqual(try incremental?.get().first { $0.id == 2 }?.description, "changed", file: file, line: line)
    }

    func prepareCustomerWithTeam() {
        var team = KimaiTeam()
        team.id = 7
        team.name = "fixture team"
        var customer = KimaiCustomerDTO()
        customer.id = 1
        customer.name = "fixture customer"
        customer.teams = [team]
        let remote = RelatedRemote<KimaiCustomerDTO>(serverID: 101)
        remote.records = [customer]
        customerService = KimaiCustomerService(customerRepository: DatabaseRepository<KimaiCustomer>("kimai_customers"),
            teamRepository: DatabaseRepository<KimaiTeam>("kimai_teams"), requestService: remote)
    }

    func synchronizeCustomerTeams() async throws { _ = try await customerService!.sync() }

    func shouldHavePersistedCustomerTeam(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(try customerService?.getTeams().map(\.id), [7], file: file, line: line)
        XCTAssertEqual(try customerService?.getTeams().first?.name, "fixture team", file: file, line: line)
        XCTAssertEqual(try customerService?.getCustomers().first?.teams, [7], file: file, line: line)
    }

    func createRelatedOfflineRecords() throws {
        let customers = DatabaseRepository<KimaiCustomer>("kimai_customers")
        let customerRequests = RelatedRemote<KimaiCustomerDTO>(serverID: 101)
        customerRemote = customerRequests
        customerService = KimaiCustomerService(customerRepository: customers,
            teamRepository: DatabaseRepository<KimaiTeam>("kimai_teams"),
            requestService: customerRequests)
        var customer = KimaiCustomer()
        customer.name = "offline customer"
        try customerService!.createCustomer(customer)

        let projects = DatabaseRepository<KimaiProject>("kimai_projects")
        projectRepository = projects
        let requests = RelatedRemote<KimaiProject>(serverID: 201)
        projectRemote = requests
        projectService = RecordService(repository: projects, requestService: requests)
        var project = KimaiProject()
        project.name = "offline project"
        project.customer = try customers.get().first!.id
        try projectService!.create(project)
        preSyncProject = try projects.get().first!
        localCustomerID = project.customer

        let activities = DatabaseRepository<KimaiActivity>("kimai_activities")
        activityRepository = activities
        let activityRequests = RelatedRemote<KimaiActivity>(serverID: 301)
        activityRemote = activityRequests
        activityService = RecordService(repository: activities, requestService: activityRequests)
        var activity = KimaiActivity()
        activity.name = "offline activity"
        activity.project = try projects.get().first!.id
        try activityService!.create(activity)

        let timesheets = DatabaseRepository<KimaiTimesheet>("kimai_timesheets")
        timesheetRepository = timesheets
        let timesheetRequests = RelatedRemote<KimaiTimesheet>(serverID: 401)
        timesheetRemote = timesheetRequests
        timesheetService = RecordService(repository: timesheets, requestService: timesheetRequests)
        var timesheet = KimaiTimesheet()
        timesheet.project = try projects.get().first!.id
        timesheet.activity = try activities.get().first!.id
        timesheet.begin = "2026-11-14T09:00:00+00:00"
        try timesheetService!.create(timesheet)
    }

    func synchronizeRelatedRecords() async throws {
        // Same customer-before-project order used by KimaiFeature's sync effect.
        _ = try await customerService!.sync()
        _ = try await projectService!.sync()
        _ = try await activityService!.sync()
        _ = try await timesheetService!.sync()
    }

    private enum ReferenceOutcome { case success, failure, timesheetFailure, accountSwitch, cancel, edit }

    func synchronizeReferenceCollections(file: StaticString = #filePath, line: UInt = #line) async throws {
        try await exerciseReferenceFetch(.success, file: file, line: line)
    }
    func rejectReferenceFetch(file: StaticString = #filePath, line: UInt = #line) async throws {
        try await exerciseReferenceFetch(.failure, file: file, line: line)
    }
    func rejectTimesheetFetch(file: StaticString = #filePath, line: UInt = #line) async throws {
        try await exerciseReferenceFetch(.timesheetFailure, file: file, line: line)
    }
    func switchAccountDuringReferenceFetch(file: StaticString = #filePath, line: UInt = #line) async throws {
        try await exerciseReferenceFetch(.accountSwitch, file: file, line: line)
    }
    func cancelReferenceFetch(file: StaticString = #filePath, line: UInt = #line) async throws {
        try await exerciseReferenceFetch(.cancel, file: file, line: line)
    }
    func editProjectDuringReferenceFetch(file: StaticString = #filePath, line: UInt = #line) async throws {
        try await exerciseReferenceFetch(.edit, file: file, line: line)
    }

    private func exerciseReferenceFetch(_ outcome: ReferenceOutcome, file: StaticString = #filePath, line: UInt = #line) async throws {
        try createRelatedOfflineRecords()
        let users = RelatedRemote<KimaiUser>(serverID: 501)
        let userService = RecordService(repository: DatabaseRepository<KimaiUser>("kimai_users"), requestService: users)
        let coordinator = KimaiSyncCoordinator()
        let gate = ReferenceFetchGate()
        let started = XCTestExpectation(description: "all five resource requests in flight")
        started.expectedFulfillmentCount = 5
        let finished = XCTestExpectation(description: "reference operation completed")
        customerRemote!.onFetch = { try await gate.wait("customers", started: started) }
        projectRemote!.onFetch = { try await gate.wait("projects", started: started) }
        activityRemote!.onFetch = { try await gate.wait("activities", started: started) }
        users.onFetch = { try await gate.wait("users", started: started) }
        customerRemote!.onInsert = { [referenceUploads] in referenceUploads.record("customers") }
        projectRemote!.onInsert = { [referenceUploads] in referenceUploads.record("projects") }
        activityRemote!.onInsert = { [referenceUploads] in referenceUploads.record("activities") }
        timesheetRemote!.onFetch = { try await gate.wait("timesheets", started: started) }
        timesheetRemote!.onInsert = { [referenceUploads] in referenceUploads.record("timesheets") }
        let operation = coordinator.operation { [self] check in
            try await coordinator.synchronizeReferenceData(customers: customerService!, projects: projectService!,
                activities: activityService!, users: userService, timesheets: timesheetService!, check: check)
        }
        let task = _Concurrency.Task {
            defer { finished.fulfill() }
            try await operation()
        }
        await testCase!.fulfillment(of: [started], timeout: 2)
        let maximum = await gate.maximum
        XCTAssertEqual(maximum, 5, file: file, line: line)
        XCTAssertTrue(referenceUploads.names.isEmpty, "No uploads before all snapshots arrive", file: file, line: line)
        switch outcome {
        case .success: break
        case .edit:
            var project = try projectService!.get().first!
            project.name = "edited during download"
            try projectService!.update(project)
        case .failure: await gate.fail("projects")
        case .timesheetFailure: await gate.fail("timesheets")
        case .accountSwitch: switchAccount(to: "b")
        case .cancel: coordinator.invalidate()
        }
        if outcome == .failure || outcome == .timesheetFailure || outcome == .cancel {
            await testCase!.fulfillment(of: [finished], timeout: 2)
        }
        await gate.release()
        let result = await task.result
        if outcome == .success || outcome == .edit { try result.get() }
        else {
            if case .success = result { XCTFail("Expected rejected reference sync", file: file, line: line) }
            let cancelled = await gate.cancelled
            if outcome == .failure { XCTAssertEqual(cancelled, ["customers", "activities", "users", "timesheets"], file: file, line: line) }
            if outcome == .timesheetFailure { XCTAssertEqual(cancelled, ["customers", "projects", "activities", "users"], file: file, line: line) }
            if outcome == .cancel { XCTAssertEqual(cancelled.count, 5, file: file, line: line) }
            if outcome == .accountSwitch {
                XCTAssertEqual(try DatabaseRepository<KimaiProject>("kimai_projects").get().count, 0, file: file, line: line)
                switchAccount(to: "a")
            }
        }
    }

    func shouldHaveUploadedLatestReferenceEdit(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(projectRemote?.uploads.first?.name, "edited during download", file: file, line: line)
        XCTAssertEqual(try projectRepository?.get().first?.name, "edited during download", file: file, line: line)
    }

    func shouldHaveOrderedReferenceUploads(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(referenceUploads.names, ["customers", "projects", "activities", "timesheets"], file: file, line: line)
    }

    func shouldHaveUnchangedReferenceChanges(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(referenceUploads.names.isEmpty, file: file, line: line)
        XCTAssertEqual(try customerService?.getCustomers().map(\.name), ["offline customer"], file: file, line: line)
        XCTAssertEqual(try projectService?.get().map(\.id), [preSyncProject!.id], file: file, line: line)
        XCTAssertEqual(try activityService?.get().count, 1, file: file, line: line)
        XCTAssertEqual(try timesheetService?.get().count, 1, file: file, line: line)
        XCTAssertEqual(try customerService?.getCustomerChanges().map(\.type), [.insert], file: file, line: line)
        XCTAssertEqual(try projectService?.getChanges().map(\.type), [.insert], file: file, line: line)
        XCTAssertEqual(try activityService?.getChanges().map(\.type), [.insert], file: file, line: line)
        XCTAssertEqual(try timesheetService?.getChanges().map(\.type), [.insert], file: file, line: line)
        XCTAssertEqual(try projectRepository?.get().first?.customer, localCustomerID, file: file, line: line)
    }

    func rejectRecordUpdates() throws {
        try connections[account]!.execute("CREATE TRIGGER fail_merge BEFORE UPDATE ON records BEGIN SELECT RAISE(ABORT, 'fixture write failure'); END;")
    }

    func rejectPendingOperationWrites() throws {
        try connections[account]!.execute("CREATE TRIGGER fail_track BEFORE INSERT ON track BEGIN SELECT RAISE(ABORT, 'fixture track failure'); END;")
    }

    func synchronize() async throws { _ = try await service.sync() }

    func shouldRejectSync(file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await synchronize()
            XCTFail("Sync must report failure instead of treating failed work as success", file: file, line: line)
        } catch { /* Failure is required; state is asserted separately by the scenario. */ }
    }

    func finishSyncAllowingCancellation() async {
        do { try await synchronize() } catch { /* Rejection is safe; cross-account writes are not. */ }
    }

    func shouldHaveRecord(_ id: Int, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(try repository.get(by: id)?.name, name, file: file, line: line)
    }

    func shouldHavePendingUpdate(_ id: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(try repository.getChanges().first { $0.recordID == id }?.type, .update, file: file, line: line)
    }

    func shouldHaveNoPendingChanges(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(try repository.getChanges().isEmpty, file: file, line: line)
    }

    func shouldHaveUploadedNothing(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(remote.creates.isEmpty && remote.updates.isEmpty, file: file, line: line)
    }

    func shouldSendBoundedIncrementalQuery(file: StaticString = #filePath, line: UInt = #line) {
        let parameters = KimaiAPI.getTimesheets(3, modifiedAfter: "2026-11-14T08:59:59").parameters
        XCTAssertEqual(parameters["page"] as? Int, 3, file: file, line: line)
        XCTAssertEqual(parameters["size"] as? Int, 500, file: file, line: line)
        XCTAssertEqual(parameters["orderBy"] as? String, "id", file: file, line: line)
        XCTAssertEqual(parameters["order"] as? String, "ASC", file: file, line: line)
        XCTAssertEqual(parameters["modified_after"] as? String, "2026-11-14T08:59:59", file: file, line: line)
        XCTAssertEqual(KimaiAPI.getTimesheet(201).path, "/timesheets/201", file: file, line: line)
        XCTAssertEqual(KimaiAPI.getTimesheet(201).method, .get, file: file, line: line)
    }

    func shouldKeepRequestBoundToAccount(file: StaticString = #filePath, line: UInt = #line) {
        let first = KimaiAuthPlugin(user: "account A", token: "token A", baseURL: URL(string: "https://a.invalid/kimai/api")!)
        let second = KimaiAuthPlugin(user: "account B", token: "token B", baseURL: URL(string: "https://b.invalid/api")!)
        let request = URLRequest(url: URL(string: "https://unconfigured.invalid/api/timesheets?page=2")!)
        _ = second.prepare(request, target: KimaiAPI.getTimesheets(2))
        let bound = first.prepare(request, target: KimaiAPI.getTimesheets(2))
        XCTAssertEqual(bound.url?.host, "a.invalid", file: file, line: line)
        XCTAssertEqual(bound.url?.path, "/kimai/api/timesheets", file: file, line: line)
        XCTAssertEqual(bound.url?.query, "page=2", file: file, line: line)
        XCTAssertEqual(bound.value(forHTTPHeaderField: "X-AUTH-USER"), "account A", file: file, line: line)
        XCTAssertEqual(bound.value(forHTTPHeaderField: "X-AUTH-TOKEN"), "token A", file: file, line: line)
    }

    func shouldRejectDifferentServerForAccountDatabase(file: StaticString = #filePath, line: UInt = #line) throws {
        let kimai = KimaiService(customers: .mock, projects: KimaiProjectService.mock,
            timesheets: KimaiTimesheetService.mock, activities: KimaiActivityService.mock, users: KimaiUserService.mock)
        kimai.setAuth(username: "fixture", password: "token A")
        _ = try kimai.login(server: "https://a.invalid")
        kimai.setAuth(username: "fixture", password: "rotated token")
        _ = try kimai.login(server: "https://a.invalid")
        XCTAssertThrowsError(try kimai.login(server: "https://b.invalid"), file: file, line: line)
    }

    func shouldIgnoreStaleCompletion(file: StaticString = #filePath, line: UInt = #line) {
        var state = KimaiFeature.State()
        state.syncID = UUID()
        state.syncStatus = .syncing
        let original = state
        _ = KimaiFeature().reduce(&state, .syncFinished(UUID(), true))
        XCTAssertEqual(state, original, file: file, line: line)
    }

    func shouldRejectOverlappingAppSyncs(file: StaticString = #filePath, line: UInt = #line) async throws {
        let coordinator = KimaiSyncCoordinator()
        let gate = SyncGate()
        let started = XCTestExpectation(description: "first sync started")
        let operation = coordinator.operation { check in
            started.fulfill()
            await gate.wait()
            try check()
        }
        let first = _Concurrency.Task { try await operation() }
        await testCase!.fulfillment(of: [started], timeout: 2)
        let rejected = XCTestExpectation(description: "overlap rejected before first sync completes")
        let second = _Concurrency.Task {
            defer { rejected.fulfill() }
            do {
                try await operation()
                XCTFail("Overlapping sync must be rejected", file: file, line: line)
            } catch {}
        }
        await testCase!.fulfillment(of: [rejected], timeout: 2)
        await gate.release()
        await second.value
        try await first.value
    }

    func shouldCancelInvalidatedAppSync(file: StaticString = #filePath, line: UInt = #line) async throws {
        let coordinator = KimaiSyncCoordinator()
        let gate = SyncGate()
        let started = XCTestExpectation(description: "sync started")
        let operation = coordinator.operation { check in
            started.fulfill()
            await gate.wait()
            try check()
            XCTFail("Old sync must not continue", file: file, line: line)
        }
        let task = _Concurrency.Task { try await operation() }
        await testCase!.fulfillment(of: [started], timeout: 2)
        coordinator.invalidate()
        await gate.release()
        do {
            try await task.value
            XCTFail("Invalidated sync must fail", file: file, line: line)
        } catch {}
    }

    func shouldHaveBoundedConcurrentPageRequests(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(pageProbe?.maximum ?? 0, 1, file: file, line: line)
        XCTAssertLessThanOrEqual(pageProbe?.maximum ?? 0, 4, file: file, line: line)
    }

    func shouldHaveRequestedAllPages(_ count: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(pages.sorted(), Array(1...count), file: file, line: line)
        XCTAssertEqual(try repository.get().map(\.id).sorted(), Array(1...count), file: file, line: line)
    }

    func shouldHaveRequestedPages(_ expected: [Int], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(pages, expected, file: file, line: line)
    }

    func shouldHaveUploadedChildWithParent(_ id: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(projectRemote?.uploads.map(\.customer), [id], file: file, line: line)
    }

    func shouldHavePersistedChildWithParent(_ id: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(try projectRepository?.get().map(\.customer), [id], file: file, line: line)
    }

    func shouldHaveRemappedRelationshipChain(file: StaticString = #filePath, line: UInt = #line) {
        shouldHaveUploadedChildWithParent(101, file: file, line: line)
        shouldHavePersistedChildWithParent(101, file: file, line: line)
        XCTAssertEqual(activityRemote?.uploads.first?.project, 201, file: file, line: line)
        XCTAssertEqual(timesheetRemote?.uploads.first?.project, 201, file: file, line: line)
        XCTAssertEqual(timesheetRemote?.uploads.first?.activity, 301, file: file, line: line)
        XCTAssertEqual(try activityRepository?.get().first?.project, 201, file: file, line: line)
        XCTAssertEqual(try timesheetRepository?.get().first?.project, 201, file: file, line: line)
        XCTAssertEqual(try timesheetRepository?.get().first?.activity, 301, file: file, line: line)
    }

    func hideProjectUsingPreUploadIdentity() throws {
        _ = try KimaiFeature().delete(preSyncProject!, service: projectService!)
    }

    func shouldHaveHiddenAcknowledgedProject(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(try projectRepository?.get(by: 201)?.visible, false, file: file, line: line)
        XCTAssertEqual(try projectRepository?.getChanges().first?.type, .update, file: file, line: line)
    }

    func createProjectUsingPreUploadCustomerIdentity() throws {
        var project = KimaiProject()
        project.name = "new project from stale picker"
        project.customer = localCustomerID!
        try projectService!.create(project)
    }

    func shouldHaveResolvedNewProjectRelationship(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(try projectRepository?.get().first { $0.name == "new project from stale picker" }?.customer, 101, file: file, line: line)
    }

    func shouldSendVisibilityAndActivityRelationship(file: StaticString = #filePath, line: UInt = #line) {
        var project = KimaiProject()
        project.id = 201
        project.visible = false
        XCTAssertEqual(KimaiAPI.updateProject(project).parameters["visible"] as? Bool, false, file: file, line: line)
        var activity = KimaiActivity()
        activity.project = 201
        XCTAssertEqual(KimaiAPI.insertActivity(activity).parameters["project"] as? Int, 201, file: file, line: line)
    }

    func shouldHaveCreatedExactlyOnce(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(remote.creates.filter { $0.name == name }.count, 1, file: file, line: line)
        XCTAssertEqual(remote.records.filter { $0.name == name }.count, 1, file: file, line: line)
        XCTAssertEqual(try repository.get().filter { $0.name == name }.count, 1, file: file, line: line)
    }

    func shouldHaveNoUntrackedLocalCreate(file: StaticString = #filePath, line: UInt = #line) throws {
        // Query SQLite directly: repository.get() swallows read errors into empty arrays.
        let untracked = try connections[account]!.scalar("""
            SELECT COUNT(*) FROM records r WHERE NOT EXISTS (
                SELECT 1 FROM track t WHERE t.tableName = 'records'
                    AND t.recordID = r.id AND t.type = ?
            )
            """, DatabaseChangeType.insert.rawValue) as? Int64
        XCTAssertEqual(untracked, 0, "A durable local create must have a durable pending operation", file: file, line: line)
    }
}
