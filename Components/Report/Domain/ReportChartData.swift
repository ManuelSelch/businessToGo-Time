import Foundation

struct ReportChartEntry {
    let date: Date
    let hours: Double
}

struct ReportChartBucket: Identifiable {
    let id: Int
    let label: String
    let accessibilityLabel: String
    let hours: Double

    var chartKey: String { String(id) }
}

enum ReportChartPeriod {
    case week, month, year
}

enum ReportChartData {
    static func buckets(period: ReportChartPeriod, selectedDate: Date, entries: [ReportChartEntry], calendar: Calendar = .current) -> [ReportChartBucket] {
        var calendar = calendar
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let component: Calendar.Component = period == .week ? .weekOfYear : (period == .month ? .month : .year)
        guard let interval = calendar.dateInterval(of: component, for: selectedDate) else { return [] }
        var start = interval.start
        var buckets: [ReportChartBucket] = []
        let weekdays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        let months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        let monthNames = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

        while start < interval.end {
            let next: Date?
            switch period {
            case .week:
                next = calendar.date(byAdding: .day, value: 1, to: start)
            case .month:
                let weekday = calendar.component(.weekday, from: start)
                let daysUntilMonday = (9 - weekday) % 7
                next = calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: start)
            case .year:
                next = calendar.date(byAdding: .month, value: 1, to: start)
            }
            guard let next = next else { break }
            let end = min(next, interval.end)
            let label: String
            switch period {
            case .week:
                label = weekdays[buckets.count]
            case .month:
                let lastDay = calendar.date(byAdding: .day, value: -1, to: end) ?? start
                label = "\(calendar.component(.day, from: start))–\(calendar.component(.day, from: lastDay))"
            case .year:
                label = months[buckets.count]
            }
            let hours = entries.lazy.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.hours }
            let accessibilityLabel = period == .year ? monthNames[buckets.count] : label
            buckets.append(ReportChartBucket(id: buckets.count, label: label, accessibilityLabel: accessibilityLabel, hours: hours))
            start = end
        }
        return buckets
    }
}
