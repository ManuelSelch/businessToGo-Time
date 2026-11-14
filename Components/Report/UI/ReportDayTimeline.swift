import SwiftUI
import CommonUI
import CommonCore
import KimaiCore
import OfflineSyncCore

struct ReportDayTimeline: View {
    let timesheets: [KimaiTimesheet]
    let projects: [KimaiProject]
    let customers: [KimaiCustomer]
    let activities: [KimaiActivity]
    let timesheetChanges: [DatabaseChange]
    let edit: (KimaiTimesheet) -> Void
    let delete: (KimaiTimesheet) -> Void

    private var inputs: [ReportTimelineInput] {
        timesheets.compactMap { entry in
            guard let begin = entry.getBeginDate() else { return nil }
            let start = Calendar.current.startOfDay(for: begin)
            let end = entry.getEndDate() ?? Date.now
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? end
            return ReportTimelineInput(id: entry.id, startMinute: begin.timeIntervalSince(start) / 60, durationMinutes: max(0, min(end, nextDay).timeIntervalSince(begin) / 60))
        }
    }

    var body: some View {
        if timesheets.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar").font(.title2)
                Text("Keine Zeiteinträge für diesen Tag")
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let entries = inputs
            let positions = ReportTimelineLayout.positions(entries)
            let range = ReportTimelineLayout.hourRange(entries) ?? 0...60
            let startOffset = Double(range.lowerBound * 2)
            ScrollView {
                    ZStack(alignment: .topLeading) {
                        ForEach((range.lowerBound / 60)...(range.upperBound / 60), id: \.self) { hour in
                            HStack(spacing: 8) {
                                Text(String(format: "%02d:00", hour))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 38, alignment: .leading)
                                Rectangle().fill(Color.secondary.opacity(0.18)).frame(height: 1)
                            }
                            .offset(y: CGFloat(hour * 120 - range.lowerBound * 2))
                        }
                        ForEach(positions, id: \.id) { position in
                            if let entry = timesheets.first(where: { $0.id == position.id }) {
                                entryCard(entry)
                                    .frame(height: CGFloat(position.height))
                                    .padding(.leading, 46)
                                    .offset(y: CGFloat(position.top - startOffset))
                            }
                        }
                    }
                    .frame(height: CGFloat(max(Double((range.upperBound - range.lowerBound) * 2), (positions.map { $0.top + $0.height }.max() ?? startOffset) - startOffset)) + 20, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
        }
    }

    private func entryCard(_ entry: KimaiTimesheet) -> some View {
        let project = projects.first { $0.id == entry.project }
        let customer = customers.first { $0.id == project?.customer }
        let activity = activities.first { $0.id == entry.activity }
        let begin = entry.getBeginDate()?.formatted(date: .omitted, time: .shortened) ?? "--:--"
        let end = entry.getEndDate()?.formatted(date: .omitted, time: .shortened) ?? "Läuft"
        return Button { edit(entry) } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: project?.color ?? "#4284DC")).frame(width: 3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(activity?.name ?? "\(entry.activity)").font(.caption.weight(.semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(customer?.name ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        if timesheetChanges.contains(where: { $0.recordID == entry.id }) {
                            Circle().fill(.red).frame(width: 7, height: 7).accessibilityLabel("Noch nicht synchronisiert")
                        }
                    }
                    HStack {
                        Text("\(begin) – \(end)")
                        Text(entry.getDuration())
                        if let name = project?.name { Text(name).lineLimit(1) }
                    }
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(maxHeight: .infinity, alignment: .top)
                Spacer(minLength: 0)
            }
            .background(Color.homeCard, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil") { edit(entry) }
            Button("Löschen", systemImage: "trash", role: .destructive) { delete(entry) }
        }
        .accessibilityLabel("\(activity?.name ?? "Zeiteintrag"), \(customer?.name ?? ""), \(begin) bis \(end), \(entry.getDuration()) Stunden")
    }
}

struct ReportWeekEntries: View {
    let timesheets: [KimaiTimesheet]
    let projects: [KimaiProject]
    let customers: [KimaiCustomer]
    let activities: [KimaiActivity]
    let timesheetChanges: [DatabaseChange]
    let edit: (KimaiTimesheet) -> Void
    let delete: (KimaiTimesheet) -> Void

    private var groups: [(Date, [KimaiTimesheet])] {
        let grouped = Dictionary(grouping: timesheets) { Calendar.current.startOfDay(for: $0.getBeginDate() ?? .now) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.begin > $1.begin }) }
    }

    var body: some View {
        if timesheets.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar").font(.title2)
                Text("Keine Zeiteinträge für diese Woche")
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(groups, id: \.0) { date, entries in
                    Section {
                        ForEach(entries, id: \.id) { entry in
                            let project = projects.first { $0.id == entry.project }
                            let customer = customers.first { $0.id == project?.customer }
                            let activity = activities.first { $0.id == entry.activity }
                            Button { edit(entry) } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(Color(hex: project?.color ?? "#4284DC")).frame(width: 7, height: 7).padding(.top, 5)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activity?.name ?? "\(entry.activity)").font(.subheadline.weight(.semibold))
                                        Text([customer?.name, project?.name].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                                        Text("\(entry.getBeginDate()?.formatted(date: .omitted, time: .shortened) ?? "--:--") – \(entry.getEndDate()?.formatted(date: .omitted, time: .shortened) ?? "Läuft")").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if timesheetChanges.contains(where: { $0.recordID == entry.id }) { Circle().fill(.red).frame(width: 7, height: 7).accessibilityLabel("Noch nicht synchronisiert") }
                                    Text(entry.getDuration()).font(.subheadline.monospacedDigit())
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Löschen", role: .destructive) { delete(entry) }
                                Button("Bearbeiten") { edit(entry) }.tint(.gray)
                            }
                            .contextMenu {
                                Button("Bearbeiten", systemImage: "pencil") { edit(entry) }
                                Button("Löschen", systemImage: "trash", role: .destructive) { delete(entry) }
                            }
                        }
                    } header: {
                        HStack {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(MyFormatter.duration(KimaiTimesheet.totalHours(of: entries)))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
