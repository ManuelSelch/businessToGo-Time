import SwiftUI
import Redux
import KimaiCore
import CommonCore
import CommonUI

struct ReportHeaderView: View {
    @Binding var selectedReportType: ReportType
    @Binding var selectedDate: Date
    @State private var showingCalendar = false

    var body: some View {
        VStack(spacing: 12) {
            Picker("Zeitraum", selection: $selectedReportType) {
                ForEach(ReportType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Vorheriger Zeitraum")
                Spacer()
                Button { showingCalendar = true } label: {
                    Label(periodLabel, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("\(selectedReportType.rawValue) auswählen: \(periodLabel)")
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("Nächster Zeitraum")
            }
            .foregroundStyle(Color.theme)
        }
        .padding()
        .sheet(isPresented: $showingCalendar) {
            ReportPeriodCalendar(selectedDate: $selectedDate, period: selectedReportType)
        }
    }

    private var periodLabel: String {
        switch selectedReportType {
        case .day:
            return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        case .week:
            let start = selectedDate.mondayWeekStart()
            let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
        case .month: return selectedDate.formatted(.dateTime.month(.wide).year())
        case .year: return selectedDate.formatted(.dateTime.year())
        }
    }

    private func move(_ offset: Int) {
        let component: Calendar.Component = selectedReportType == .month ? .month : (selectedReportType == .year ? .year : .day)
        let amount = selectedReportType == .week ? offset * 7 : offset
        if let date = Calendar.current.date(byAdding: component, value: amount, to: selectedDate) { selectedDate = date }
    }
}

private struct ReportPeriodCalendar: View {
    @Binding var selectedDate: Date
    let period: ReportType
    @Environment(\.dismiss) private var dismiss
    @State private var displayed: Date
    private let calendar = Calendar.current
    private let days = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let grid = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    init(selectedDate: Binding<Date>, period: ReportType) {
        self._selectedDate = selectedDate
        self.period = period
        self._displayed = State(initialValue: selectedDate.wrappedValue)
    }

    private var year: Int { calendar.component(.year, from: displayed) }
    private var firstYear: Int { (year / 12) * 12 }
    private var monthStart: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: displayed)) ?? displayed }
    private var heading: String {
        if period == .year { return "\(firstYear) – \(firstYear + 11)" }
        if period == .month { return String(year) }
        return monthStart.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button { navigate(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Zurück")
                    Spacer()
                    Text(heading).font(.headline)
                    Spacer()
                    Button { navigate(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel("Weiter")
                }.foregroundStyle(Color.theme)
                if period == .week || period == .day {
                    LazyVGrid(columns: days, spacing: 4) {
                        ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                        ForEach(0..<42, id: \.self) { offset in
                            let date = calendar.date(byAdding: .day, value: offset, to: monthStart.mondayWeekStart()) ?? monthStart
                            Button { select(date) } label: {
                                Text(date.formatted(.dateTime.day()))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(isSelected(date) ? Color.theme : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(isSelected(date) ? Color.themeForeground : (calendar.isDate(date, equalTo: monthStart, toGranularity: .month) ? Color.contrast : Color.gray))
                            }.accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        }
                    }
                    if period == .week {
                        Text("Wähle einen Tag, um die ganze Woche auszuwählen.").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    LazyVGrid(columns: grid, spacing: 8) {
                        ForEach(0..<12, id: \.self) { index in
                            let targetYear = period == .year ? firstYear + index : year
                            let month = period == .month ? index + 1 : calendar.component(.month, from: selectedDate)
                            let date = calendar.date(from: DateComponents(year: targetYear, month: month, day: 1)) ?? displayed
                            let selected = calendar.isDate(date, equalTo: selectedDate, toGranularity: period == .year ? .year : .month)
                            Button { select(date) } label: {
                                Text(period == .year ? String(targetYear) : date.formatted(.dateTime.month(.abbreviated)))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(selected ? Color.theme : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(selected ? Color.themeForeground : Color.contrast)
                            }
                        }
                    }
                }
                Button(period == .day ? "Heute" : period == .month ? "Dieser Monat" : period == .year ? "Dieses Jahr" : "Diese Woche") { select(Date.today) }
                    .frame(maxWidth: .infinity).padding(10)
                    .background(Color.theme.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.theme)
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("\(period.rawValue) auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Schließen") } }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        period == .day ? calendar.isDate(date, inSameDayAs: selectedDate) : date.isInMondayWeek(of: selectedDate)
    }

    private func navigate(_ offset: Int) {
        let component: Calendar.Component = period == .week || period == .day ? .month : .year
        let amount = period == .year ? offset * 12 : offset
        if let date = calendar.date(byAdding: component, value: amount, to: displayed) { displayed = date }
    }
    private func select(_ date: Date) { selectedDate = date; dismiss() }
}
