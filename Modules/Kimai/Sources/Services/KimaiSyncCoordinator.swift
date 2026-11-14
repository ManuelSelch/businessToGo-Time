import Foundation
import SQLite
import Dependencies
import OfflineSyncCore

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
