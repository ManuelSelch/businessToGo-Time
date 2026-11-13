import SwiftUI
import Redux

import KimaiCore
import CommonCore
import CommonUI

struct ReportHeaderView: View {
    @Binding var selectedReportType: ReportType
    @Binding var selectedDate: Date
    @Binding var selectedProject: Int?
    
    var projects: [KimaiProject]
    @State private var showingWeekCalendar = false
    
    var calendarTapped: () -> ()
    var filterTapped: () -> ()
    var playTapped: () -> ()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: filterTapped) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Berichte filtern")
                
                let reportTypes = ReportType.allCases.filter({$0 != .day})
                Picker("Report Date", selection: $selectedReportType){
                    ForEach(reportTypes) { option in
                        Text(option.rawValue)
                        
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accentColor(Color.contrast)
                
                Button(action: playTapped){
                    Image(systemName: "play.fill")
                        .foregroundColor(Color.theme)
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Zeiteintrag erstellen")
            }
            .font(.system(size: 20))
            .foregroundStyle(Color.theme)
            
            switch(selectedReportType){
            case .day:
                ReportHeaderWeeks(selectedDate: $selectedDate)
            case .week:
                weekNavigation
            case .month:
                HStack {
                    Image(systemName: "arrow.left")
                    Spacer()
                    Text("Dez. 2024")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding()
            case .year: EmptyView()
            }
            
            
        }
        .padding()
        .foregroundStyle(Color.contrast)
        .sheet(isPresented: $showingWeekCalendar) {
            ReportWeekCalendar(selectedDate: $selectedDate)
        }
    }

    private var weekNavigation: some View {
        let start = selectedDate.mondayWeekStart()
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start

        return HStack {
            Button { moveWeek(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Vorherige Woche")
            Spacer()
            Button { showingWeekCalendar = true } label: {
                Label("\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.theme.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Woche auswählen")
            Spacer()
            Button { moveWeek(1) } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Nächste Woche")
        }
        .foregroundStyle(Color.theme)
        .padding(.top, 16)
    }

    private func moveWeek(_ offset: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: offset * 7, to: selectedDate) else { return }
        selectedDate = date
    }
}

private struct ReportWeekCalendar: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Vorheriger Monat")
                    Spacer()
                    Text(monthStart.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Nächster Monat")
                }
                .foregroundStyle(Color.theme)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { day in
                        Text(day).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(0..<42, id: \.self) { offset in
                        let date = calendar.date(byAdding: .day, value: offset, to: monthStart.mondayWeekStart()) ?? monthStart
                        Button {
                            selectedDate = date
                            dismiss()
                        } label: {
                            Text(date.formatted(.dateTime.day()))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(date.isInMondayWeek(of: selectedDate) ? Color.theme : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(date.isInMondayWeek(of: selectedDate) ? Color.themeForeground : (calendar.isDate(date, equalTo: monthStart, toGranularity: .month) ? Color.contrast : Color.gray))
                        }
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    }
                }

                Button("Diese Woche") {
                    selectedDate = Date.today
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color.theme.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.theme)
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Woche auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func moveMonth(_ offset: Int) {
        guard let date = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return }
        displayedMonth = date
    }
}
