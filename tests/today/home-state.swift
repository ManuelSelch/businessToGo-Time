import Foundation

@main
struct HomeStateTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 10_000)
        let entries = [
            HomeEntry(projectID: 2, started: now.addingTimeInterval(-300)),
            HomeEntry(projectID: 1, started: now.addingTimeInterval(-100)),
            HomeEntry(projectID: 2, started: now.addingTimeInterval(-50)),
            HomeEntry(projectID: 3, started: nil),
            HomeEntry(projectID: 4, started: now.addingTimeInterval(-200))
        ]
        precondition(HomeState.recentProjectIDs(entries, validProjectIDs: [1, 2, 3, 4]) == [2, 1, 4])
        precondition(HomeState.recentProjectIDs(entries, validProjectIDs: [1]) == [1])
        precondition(HomeState.duration(since: now.addingTimeInterval(-3720), now: now) == "01:02")
        precondition(HomeState.duration(since: now.addingTimeInterval(60), now: now) == "00:00")
        print("Home state tests passed")
    }
}
