import Foundation

struct ReportTimelineInput {
    let id: Int
    let startMinute: Double
    let durationMinutes: Double
}

struct ReportTimelinePosition {
    let id: Int
    let top: Double
    let height: Double
}

enum ReportTimelineLayout {
    static func hourRange(_ entries: [ReportTimelineInput]) -> ClosedRange<Int>? {
        guard let earliest = entries.map(\.startMinute).min(),
              let latest = entries.map({ $0.startMinute + $0.durationMinutes }).max() else { return nil }
        let start = max(0, min(23, Int(floor(earliest / 60)))) * 60
        let end = min(1440, max(start + 60, Int(ceil(latest / 60)) * 60))
        return start...end
    }

    static func positions(_ entries: [ReportTimelineInput]) -> [ReportTimelinePosition] {
        var bottom: Double = 0
        return entries.sorted { $0.startMinute == $1.startMinute ? $0.id < $1.id : $0.startMinute < $1.startMinute }.map { entry in
            let top = max(entry.startMinute * 2, bottom)
            let height = max(40, entry.durationMinutes * 2)
            bottom = top + height
            return ReportTimelinePosition(id: entry.id, top: top, height: height)
        }
    }
}
