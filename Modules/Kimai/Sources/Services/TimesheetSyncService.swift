import Foundation
import SQLite
import OfflineSyncCore
import OfflineSyncServices
import KimaiCore

/// Persistent, server-clock-based modified_after checkpoint, scoped to the account DB.
final class TimesheetSyncService: RecordService<KimaiTimesheet> {
    private let pages: PageRequestService<KimaiTimesheet, KimaiAPI>

    init(repository: DatabaseRepository<KimaiTimesheet>, pages: PageRequestService<KimaiTimesheet, KimaiAPI>) {
        self.pages = pages
        super.init(repository: repository, requestService: pages)
    }

    override func sync() async throws -> [KimaiTimesheet] {
        let session = try SyncSession(connection: repository.connection())
        try session.check()
        let state = try repository.transaction(on: session.connection) { db -> (Int64?, Int64?, Int64) in
            try db.execute("CREATE TABLE IF NOT EXISTS kimai_sync_checkpoint (id INTEGER PRIMARY KEY, checkpoint INTEGER, observed INTEGER, deltaCount INTEGER NOT NULL)")
            let checkpoint = try db.scalar("SELECT checkpoint FROM kimai_sync_checkpoint WHERE id = 1") as? Int64
            let observed = try db.scalar("SELECT observed FROM kimai_sync_checkpoint WHERE id = 1") as? Int64
            let deltaCount = try db.scalar("SELECT deltaCount FROM kimai_sync_checkpoint WHERE id = 1") as? Int64 ?? 0
            return (checkpoint, observed, deltaCount)
        }
        // Periodically revalidate the full history: HTTP Date may be supplied by a
        // proxy clock, and modified_after does not expose deletions or a server cursor.
        var checkpoint = state.2 >= 19 ? nil : state.0
        var previousObserved = state.1
        let cursor = checkpoint.map(Self.format)
        pages.fetchPageMethod = { KimaiAPI.getTimesheets($0, modifiedAfter: cursor) }
        var remote = try await pages.fetch()
        try session.check()
        if let observed = pages.observedServerDate, let previous = previousObserved,
           observed.timeIntervalSince1970 < Double(previous) {
            // A server clock rollback invalidates the watermark. Rebuild without
            // using the device clock or guessing an overlap duration.
            checkpoint = nil
            previousObserved = nil
            pages.fetchPageMethod = { KimaiAPI.getTimesheets($0) }
            remote = try await pages.fetch()
            try session.check()
        }
        let records = try await synchronize(remote, session: session, incremental: checkpoint != nil,
            remoteLookup: { [pages] id in
                do {
                    return try await pages.request(pages.provider, KimaiAPI.getTimesheet(id))
                } catch ServiceError.httpStatus(404) { return nil }
            })
        try session.check()
        if let observed = pages.observedServerDate {
            try repository.transaction(on: session.connection) { db in
                // Lag one successful scan: the PREVIOUS response Date predates this
                // scan's SELECTs. Advancing to this response's Date could skip writes
                // committed between the SELECT and response generation. Overlap one
                // second because Kimai modified_after has whole-second precision.
                let next = previousObserved.map { $0 - 1 }
                try db.run("INSERT OR REPLACE INTO kimai_sync_checkpoint (id, checkpoint, observed, deltaCount) VALUES (1, ?, ?, ?)",
                    next, Int64(observed.timeIntervalSince1970), checkpoint == nil ? 0 : state.2 + 1)
            }
        } else {
            // Without a trustworthy clock observation, do not keep advancing a delta session.
            try repository.transaction(on: session.connection) { db in
                try db.run("DELETE FROM kimai_sync_checkpoint WHERE id = 1")
            }
        }
        return records
    }

    private static func format(_ timestamp: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
    }
}
