import Foundation
import SQLite
import Dependencies
import OfflineSyncCore
import OfflineSyncServices
import KimaiCore

/// Owns cancellation/generation across all entity stages, not just one HTTP call.
final class KimaiSyncCoordinator {
    @Dependency(\.database) private var database
    private let lock = NSLock()
    private var generation = UUID()
    private var running: (UUID, Task<Void, Error>)?

    func invalidate() {
        lock.lock()
        generation = UUID()
        let task = running?.1
        running = nil
        lock.unlock()
        task?.cancel()
    }

    func operation(_ work: @escaping (@escaping () throws -> Void) async throws -> Void) -> () async throws -> Void {
        lock.lock()
        let expected = generation
        let connection = database.connection
        lock.unlock()
        let check = { [self] in
            try Task.checkCancellation()
            lock.lock()
            let current = generation
            lock.unlock()
            guard current == expected, let connection = connection, database.connection === connection else {
                throw ServiceError.accountChanged
            }
        }
        return { [self] in
            let (id, task) = try start(expected: expected) {
                try check()
                try await work(check)
                try check()
            }
            defer { finish(id) }
            try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        }
    }

    private enum ReferenceSnapshot {
        case customers([KimaiCustomer], [KimaiTeam])
        case projects([KimaiProject])
        case activities([KimaiActivity])
        case users([KimaiUser])
        case timesheets(TimesheetSnapshot)
    }

    private enum TimesheetSnapshot {
        case incremental(TimesheetSyncService.Snapshot)
        case full([KimaiTimesheet])
    }

    private struct ReferenceSnapshots {
        var customers: [KimaiCustomer] = []
        var teams: [KimaiTeam] = []
        var projects: [KimaiProject] = []
        var activities: [KimaiActivity] = []
        var users: [KimaiUser] = []
        var timesheets: TimesheetSnapshot?
    }

    func synchronizeReferenceData(customers: KimaiCustomerService, projects: RecordService<KimaiProject>,
                                  activities: RecordService<KimaiActivity>, users: RecordService<KimaiUser>,
                                  timesheets: RecordService<KimaiTimesheet>, check: @escaping () throws -> Void) async throws {
        try check()
        // One lease covers the whole batch. Child tasks fetch only; none acquire
        // another lease, write SQLite or acknowledge pending operations.
        let session = try SyncSession(connection: projects.repository.connection())
        try session.check()
        let incrementalTimesheets = timesheets as? TimesheetSyncService
        let timesheetState = try incrementalTimesheets?.prepareFetch(session: session)
        let snapshots = try await withThrowingTaskGroup(of: ReferenceSnapshot.self) { group -> ReferenceSnapshots in
            group.addTask {
                try check()
                let (records, teams) = try await customers.fetch()
                try check()
                return .customers(records, teams)
            }
            group.addTask {
                try check()
                let records = try await projects.fetch()
                try check()
                return .projects(records)
            }
            group.addTask {
                try check()
                let records = try await activities.fetch()
                try check()
                return .activities(records)
            }
            group.addTask {
                try check()
                let records = try await users.fetch()
                try check()
                return .users(records)
            }
            group.addTask {
                try check()
                let snapshot: TimesheetSnapshot
                if let service = incrementalTimesheets, let state = timesheetState {
                    snapshot = .incremental(try await service.fetchSnapshot(state: state, session: session))
                } else {
                    snapshot = .full(try await timesheets.fetch())
                }
                try check()
                return .timesheets(snapshot)
            }
            var result = ReferenceSnapshots()
            // A failed fetch throws immediately and cancels/drains its siblings.
            // Do not start reconciliation until every collection has arrived.
            for try await snapshot in group {
                switch snapshot {
                case let .customers(records, teams): result.customers = records; result.teams = teams
                case let .projects(records): result.projects = records
                case let .activities(records): result.activities = records
                case let .users(records): result.users = records
                case let .timesheets(snapshot): result.timesheets = snapshot
                }
            }
            return result
        }
        try check()
        try session.check()
        _ = try await customers.synchronize(remoteCustomers: snapshots.customers, remoteTeams: snapshots.teams, session: session)
        try check()
        _ = try await projects.synchronize(snapshots.projects, session: session)
        try check()
        _ = try await activities.synchronize(snapshots.activities, session: session)
        try check()
        _ = try await users.synchronize(snapshots.users, session: session)
        try check()
        switch snapshots.timesheets {
        case let .incremental(snapshot):
            guard let service = incrementalTimesheets else { throw ServiceError.accountChanged }
            _ = try await service.synchronize(snapshot: snapshot, session: session)
        case let .full(records):
            _ = try await timesheets.synchronize(records, session: session)
        case nil:
            throw ServiceError.accountChanged
        }
        try check()
    }

    private func start(expected: UUID, work: @escaping () async throws -> Void) throws -> (UUID, Task<Void, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expected else { throw ServiceError.accountChanged }
        guard running == nil else { throw ServiceError.syncInProgress }
        let id = UUID()
        let task = Task { try await work() }
        running = (id, task)
        return (id, task)
    }

    private func finish(_ id: UUID) {
        lock.lock()
        if running?.0 == id { running = nil }
        lock.unlock()
    }
}
