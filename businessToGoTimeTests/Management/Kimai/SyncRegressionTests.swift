import XCTest
import Foundation
import SQLite
import Moya
import Dependencies
import OfflineSyncCore
import OfflineSyncServices
import KimaiCore
@testable import KimaiServices

// Run serially: the pinned Dependencies library has process-global mutable storage.
final class SyncRegressionTests: XCTestCase {
    private var sync: SyncRegressionDriver!

    override func setUpWithError() throws {
        sync = try SyncRegressionDriver()
    }

    override func tearDownWithError() throws {
        try sync?.close()
        sync = nil
    }

    func testFailedFetchPreservesCachedRecordsAndPendingEdits() async throws {
        sync.cacheRecord(1, named: "cached")
        sync.cacheRecord(2, named: "original")
        sync.editRecord(2, named: "offline edit")
        sync.failNextFetch()

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(1, named: "cached")
        sync.shouldHaveRecord(2, named: "offline edit")
        sync.shouldHavePendingUpdate(2)
        sync.shouldHaveUploadedNothing()
    }

    func testLaterPageFailureDoesNotReconcilePartialSnapshot() async throws {
        sync.cacheRecord(99, named: "last page cached")
        sync.usePaginatedRemote(totalPages: "2", failSecondPage: true)

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(99, named: "last page cached")
        sync.shouldHaveRequestedPages([1, 2])
    }

    func testMissingPaginationMetadataDoesNotAuthorizeDeletion() async throws {
        sync.cacheRecord(99, named: "unseen cached")
        sync.usePaginatedRemote(totalPages: nil)

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(99, named: "unseen cached")
    }

    func testMalformedPaginationMetadataDoesNotAuthorizeDeletion() async throws {
        sync.cacheRecord(99, named: "unseen cached")
        sync.usePaginatedRemote(totalPages: "not-a-number")

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(99, named: "unseen cached")
    }

    func testCompletePaginationPersistsEveryPage() async throws {
        sync.usePaginatedRemote(totalPages: "2")

        try await sync.synchronize()

        sync.shouldHaveRecord(1, named: "page 1")
        sync.shouldHaveRecord(2, named: "page 2")
        sync.shouldHaveRequestedPages([1, 2])
    }

    func testEditDuringUploadSurvivesOlderAcknowledgement() async throws {
        sync.cacheRecord(1, named: "original")
        sync.editRecord(1, named: "first edit")
        sync.editAgainDuringUpload(1, named: "newer edit")

        try await sync.synchronize()

        sync.shouldHaveRecord(1, named: "newer edit")
        sync.shouldHavePendingUpdate(1)
    }

    func testLocalAndRemoteIDCollisionKeepsBothRecords() async throws {
        sync.createRecord(named: "offline create")
        sync.addRemoteRecord(1, named: "other device create")
        sync.assignNextServerID(10)

        try await sync.synchronize()

        sync.shouldHaveRecord(1, named: "other device create")
        sync.shouldHaveRecord(10, named: "offline create")
        sync.shouldHaveNoPendingChanges()
    }

    func testParentServerIDIsUsedForChildUploadAndPersistence() async throws {
        sync.createRelatedOfflineRecords()

        try await sync.synchronizeRelatedRecords()

        sync.shouldHaveUploadedChildWithParent(101)
        sync.shouldHavePersistedChildWithParent(101)
    }

    func testInterruptedUploadDoesNotRepeatAcknowledgedCreateAfterReopen() async throws {
        sync.createRecord(named: "first create")
        sync.createRecord(named: "second create")
        sync.failSecondUploadOnce()

        await sync.shouldRejectSync()
        try sync.reopenCurrentAccount()
        try await sync.synchronize()

        sync.shouldHaveCreatedExactlyOnce("first create")
        sync.shouldHaveCreatedExactlyOnce("second create")
        sync.shouldHaveNoPendingChanges()
    }

    func testFailedLocalMergeDoesNotAcknowledgePendingEdit() async throws {
        sync.cacheRecord(1, named: "original")
        sync.editRecord(1, named: "offline edit")
        try sync.rejectRecordUpdates()

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(1, named: "offline edit")
        sync.shouldHavePendingUpdate(1)
    }

    func testRecordAndPendingOperationAreAtomicOnDatabaseFailure() throws {
        try sync.rejectPendingOperationWrites()

        sync.createRecord(named: "must not become untracked")

        try sync.shouldHaveNoUntrackedLocalCreate()
    }

    func testAccountSwitchDuringFetchCannotWriteIntoNewAccount() async throws {
        sync.cacheRecord(1, named: "account A")
        sync.switchAccount(to: "b")
        sync.cacheRecord(1, named: "account B")
        sync.switchAccount(to: "a")
        sync.switchToAccountDuringFetch("b")

        await sync.finishSyncAllowingCancellation()

        sync.shouldHaveRecord(1, named: "account B")
        sync.switchAccount(to: "a")
        sync.shouldHaveRecord(1, named: "account A")
    }

    func testAccountCachesRemainSeparateAcrossSwitchAndReopen() throws {
        sync.cacheRecord(1, named: "account A")
        sync.switchAccount(to: "b")
        sync.cacheRecord(1, named: "account B")
        try sync.reopenCurrentAccount()

        sync.shouldHaveRecord(1, named: "account B")
        sync.switchAccount(to: "a")
        sync.shouldHaveRecord(1, named: "account A")
    }
}

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
    var onUpdate: (() -> Void)?

    func setPlugins(_ plugins: [PluginType]) {}

    func fetch() async throws -> [SyncRecord] {
        onFetch?()
        if fetchError { throw FixtureFailure.fetch }
        return records
    }

    func insert(_ model: SyncRecord) async throws -> SyncRecord {
        if failSecondUpload && creates.count == 1 {
            failSecondUpload = false
            throw FixtureFailure.upload
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
        onUpdate?()
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
    let serverID: Int

    init(serverID: Int) { self.serverID = serverID }
    func setPlugins(_ plugins: [PluginType]) {}
    func fetch() async throws -> [Model] { [] }
    func insert(_ model: Model) async throws -> Model {
        uploads.append(model)
        var result = model
        result.id = serverID
        return result
    }
    func update(_ model: Model) async throws -> Model { throw FixtureFailure.unexpectedNetwork }
    func delete(_ id: Int) async throws { throw FixtureFailure.unexpectedNetwork }
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
private final class SyncRegressionDriver {
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
    private var projectService: RecordService<KimaiProject>?
    private var projectRepository: DatabaseRepository<KimaiProject>?
    private var projectRemote: RelatedRemote<KimaiProject>?
    private var pages: [Int] = []

    init() throws {
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
        database.deleteAllDBs = { XCTFail("Unexpected global reset") }
        DependencyValues[\.database] = database
        DependencyValues[\.track] = TrackTable()
        makeService()
    }

    func close() throws {
        service = nil
        customerService = nil
        projectService = nil
        projectRepository = nil
        repository = nil
        connections.removeAll()
        DependencyValues[\.database] = previousDatabase
        DependencyValues[\.track] = previousTrack
        DependencyValues.mode = previousMode
        try FileManager.default.removeItem(at: directory)
    }

    private func makeService() {
        repository = DatabaseRepository("records")
        service = RecordService(repository: repository, requestService: remote)
    }

    func cacheRecord(_ id: Int, named name: String) {
        repository.insert(SyncRecord(id, name), isTrack: false)
        remote.records.append(SyncRecord(id, name))
    }

    func editRecord(_ id: Int, named name: String) { service.update(SyncRecord(id, name)) }
    func createRecord(named name: String) { service.create(SyncRecord(-1, name)) }
    func addRemoteRecord(_ id: Int, named name: String) { remote.records.append(SyncRecord(id, name)) }
    func assignNextServerID(_ id: Int) { remote.nextID = id }
    func failNextFetch() { remote.fetchError = true }
    func failSecondUploadOnce() { remote.failSecondUpload = true }

    func editAgainDuringUpload(_ id: Int, named name: String) {
        remote.onUpdate = { [unowned self] in self.editRecord(id, named: name) }
    }

    func switchAccount(to name: String) {
        precondition(connections[name] != nil)
        account = name
        // Ensure synthetic schemas exist in both accounts, just as repository.get does.
        _ = repository?.get()
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
        makeService()
    }

    func usePaginatedRemote(totalPages: String?, failSecondPage: Bool = false) {
        let provider = MoyaProvider<PageAPI>(endpointClosure: { [unowned self] target in
            guard case let .page(page) = target else { fatalError("Unknown fixture page") }
            self.pages.append(page)
            let response: EndpointSampleResponse
            if failSecondPage && page == 2 {
                response = .networkError(NSError(domain: "sync-fixture", code: 1))
            } else {
                let headers = totalPages.map { ["X-Total-Pages": $0] } ?? [:]
                let http = HTTPURLResponse(url: target.baseURL, statusCode: 200, httpVersion: nil, headerFields: headers)!
                response = .response(http, try! JSONEncoder().encode([SyncRecord(page, "page \(page)")]))
            }
            return Endpoint(url: target.baseURL.appendingPathComponent(target.path).absoluteString,
                            sampleResponseClosure: { response }, method: .get, task: .requestPlain, httpHeaderFields: nil)
        }, stubClosure: MoyaProvider.immediatelyStub)
        let request = PageRequestService<SyncRecord, PageAPI>(fetchMethod: PageAPI.page, provider: provider,
            _setPlugins: { _ in
                XCTFail("Unexpected transport replacement")
                return provider
            })
        service = RecordService(repository: repository, requestService: request)
    }

    func createRelatedOfflineRecords() {
        let customers = DatabaseRepository<KimaiCustomer>("kimai_customers")
        customerService = KimaiCustomerService(customerRepository: customers,
            teamRepository: DatabaseRepository<KimaiTeam>("kimai_teams"),
            requestService: RelatedRemote<KimaiCustomerDTO>(serverID: 101))
        var customer = KimaiCustomer()
        customer.name = "offline customer"
        customerService!.createCustomer(customer)

        let projects = DatabaseRepository<KimaiProject>("kimai_projects")
        projectRepository = projects
        let requests = RelatedRemote<KimaiProject>(serverID: 201)
        projectRemote = requests
        projectService = RecordService(repository: projects, requestService: requests)
        var project = KimaiProject()
        project.name = "offline project"
        project.customer = customers.get().first!.id
        projectService!.create(project)
    }

    func synchronizeRelatedRecords() async throws {
        // Same customer-before-project order used by KimaiFeature's sync effect.
        _ = try await customerService!.sync()
        _ = try await projectService!.sync()
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
        XCTAssertEqual(repository.get(by: id)?.name, name, file: file, line: line)
    }

    func shouldHavePendingUpdate(_ id: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(repository.getChanges().first { $0.recordID == id }?.type, .update, file: file, line: line)
    }

    func shouldHaveNoPendingChanges(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(repository.getChanges().isEmpty, file: file, line: line)
    }

    func shouldHaveUploadedNothing(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(remote.creates.isEmpty && remote.updates.isEmpty, file: file, line: line)
    }

    func shouldHaveRequestedPages(_ expected: [Int], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(pages, expected, file: file, line: line)
    }

    func shouldHaveUploadedChildWithParent(_ id: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(projectRemote?.uploads.map(\.customer), [id], file: file, line: line)
    }

    func shouldHavePersistedChildWithParent(_ id: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(projectRepository?.get().map(\.customer), [id], file: file, line: line)
    }

    func shouldHaveCreatedExactlyOnce(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(remote.creates.filter { $0.name == name }.count, 1, file: file, line: line)
        XCTAssertEqual(remote.records.filter { $0.name == name }.count, 1, file: file, line: line)
        XCTAssertEqual(repository.get().filter { $0.name == name }.count, 1, file: file, line: line)
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
