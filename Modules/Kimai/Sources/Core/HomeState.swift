import Foundation

public struct HomeEntry {
    public let projectID: Int
    public let started: Date?

    public init(projectID: Int, started: Date?) {
        self.projectID = projectID
        self.started = started
    }
}

public enum HomeState {
    public static func recentProjectIDs(_ entries: [HomeEntry], validProjectIDs: Set<Int>) -> [Int] {
        var seen = Set<Int>()
        return entries.compactMap { entry -> (Int, Date)? in
            guard let date = entry.started, validProjectIDs.contains(entry.projectID) else { return nil }
            return (entry.projectID, date)
        }
        .sorted { $0.1 > $1.1 }
        .compactMap { seen.insert($0.0).inserted ? $0.0 : nil }
        .prefix(3).map { $0 }
    }

    public static func duration(since start: Date, now: Date) -> String {
        let minutes = Int(max(0, now.timeIntervalSince(start))) / 60
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
