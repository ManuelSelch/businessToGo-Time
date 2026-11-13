import Foundation

public enum CustomerSearch {
    public static func includes(name: String, projectNames: [String], teams: [Int], selectedTeam: Int?, query: String) -> Bool {
        if let selectedTeam, !teams.contains(selectedTeam) { return false }
        return matches(name: name, projectNames: projectNames, query: query)
    }

    public static func projectMatches(customerName: String, projectName: String, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return true }
        return customerName.localizedCaseInsensitiveContains(query) || projectName.localizedCaseInsensitiveContains(query)
    }

    public static func matches(name: String, projectNames: [String], query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return true }
        return name.localizedCaseInsensitiveContains(query)
            || projectNames.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}
