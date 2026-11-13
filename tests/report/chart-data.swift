import Foundation

@main
struct ReportChartDataTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        let records = [
            ReportChartEntry(date: date(2025, 10, 31), hours: 7),
            ReportChartEntry(date: date(2025, 11, 1), hours: 1),
            ReportChartEntry(date: date(2025, 11, 2), hours: 2),
            ReportChartEntry(date: date(2025, 11, 3), hours: 4),
            ReportChartEntry(date: date(2025, 11, 30), hours: 8),
            ReportChartEntry(date: date(2025, 12, 1), hours: 16)
        ]

        let month = ReportChartData.buckets(period: .month, selectedDate: date(2025, 11, 13), entries: records, calendar: calendar)
        precondition(month.map(\.label) == ["1–2", "3–9", "10–16", "17–23", "24–30"])
        precondition(month.map(\.hours) == [3, 4, 0, 0, 8])

        let year = ReportChartData.buckets(period: .year, selectedDate: date(2025, 11, 13), entries: records, calendar: calendar)
        precondition(year.count == 12 && year[9].hours == 7 && year[10].hours == 15 && year[11].hours == 16)
        precondition(year[0].accessibilityLabel == "Januar" && year[5].accessibilityLabel == "Juni")
        precondition(Set(year.map(\.chartKey)).count == 12)
        precondition(year[0].chartKey != year[5].chartKey && year[0].label == year[5].label)

        let week = ReportChartData.buckets(period: .week, selectedDate: date(2025, 11, 2), entries: records, calendar: calendar)
        precondition(week.map(\.label) == ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
        precondition(week.map(\.hours) == [0, 0, 0, 0, 7, 1, 2])

        let emptyYear = ReportChartData.buckets(period: .year, selectedDate: date(2026, 1, 1), entries: records, calendar: calendar)
        precondition(emptyYear.count == 12 && emptyYear.allSatisfy { $0.hours == 0 })

        let dst = ReportChartData.buckets(period: .month, selectedDate: date(2024, 3, 15), entries: [ReportChartEntry(date: date(2024, 3, 31), hours: 3)], calendar: calendar)
        precondition(dst.last?.hours == 3 && dst.last?.label == "25–31")
        print("Report chart data tests passed")
    }
}
