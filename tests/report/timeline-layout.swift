import Foundation

@main
struct ReportTimelineLayoutTests {
    static func main() {
        let entries = [
            ReportTimelineInput(id: 1, startMinute: 540, durationMinutes: 5),
            ReportTimelineInput(id: 2, startMinute: 550, durationMinutes: 5),
            ReportTimelineInput(id: 3, startMinute: 560, durationMinutes: 5),
            ReportTimelineInput(id: 4, startMinute: 600, durationMinutes: 45)
        ]
        let result = ReportTimelineLayout.positions(entries)
        precondition(result.map(\.top) == [1080, 1120, 1160, 1200])
        precondition(result.map(\.height) == [40, 40, 40, 90])
        let overlapping = ReportTimelineLayout.positions([
            ReportTimelineInput(id: 5, startMinute: 600, durationMinutes: 45),
            ReportTimelineInput(id: 6, startMinute: 615, durationMinutes: 45)
        ])
        precondition(overlapping.map(\.top) == [1200, 1290])
        precondition(ReportTimelineLayout.positions([]).isEmpty)
        let unordered = ReportTimelineLayout.positions([entries[3], entries[0]])
        precondition(unordered.map(\.id) == [1, 4] && unordered[1].top == 1200)
        let range = ReportTimelineLayout.hourRange(entries)
        precondition(range?.lowerBound == 540 && range?.upperBound == 660)
        precondition(ReportTimelineLayout.hourRange([ReportTimelineInput(id: 7, startMinute: 855, durationMinutes: 5)]) == 840...900)
        precondition(ReportTimelineLayout.hourRange([ReportTimelineInput(id: 8, startMinute: 1365, durationMinutes: 75)]) == 1320...1440)
        precondition(ReportTimelineLayout.hourRange([]) == nil)
        print("Report timeline layout tests passed")
    }
}
