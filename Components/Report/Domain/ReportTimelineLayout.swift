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
