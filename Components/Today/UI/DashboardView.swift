import SwiftUI

import CommonUI
import KimaiCore

struct DashboardView: View {
    let timesheets: [KimaiTimesheet]
    let customers: [KimaiCustomer]
    let projects: [KimaiProject]
    let activities: [KimaiActivity]
    let projectTapped: (KimaiProject) -> Void
    let browseTapped: () -> Void
    let createTapped: () -> Void
    let stopTapped: (KimaiTimesheet) -> Void

    private var active: KimaiTimesheet? {
        timesheets.first { $0.end == nil }
    }

    private var recentProjects: [KimaiProject] {
        let ids = HomeState.recentProjectIDs(
            timesheets.map { HomeEntry(projectID: $0.project, started: $0.getBeginDate()) },
            validProjectIDs: Set(projects.map(\.id))
        )
        return ids.compactMap { id in projects.first { $0.id == id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                timerPanel

                HStack {
                    Text("Letzte Projekte").font(.headline)
                    Spacer()
                    Button("Alle", action: browseTapped)
                        .accessibilityLabel("Alle Kunden und Projekte anzeigen")
                }

                if recentProjects.isEmpty {
                    Text("Noch keine zuletzt verwendeten Projekte.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(recentProjects) { project in
                            Button { projectTapped(project) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(Color.theme)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.name).font(.subheadline.weight(.semibold))
                                        if let customer = customers.first(where: { $0.id == project.customer }) {
                                            Text(customer.name).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if project.id != recentProjects.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .padding(18)
        }
    }

    private var timerPanel: some View {
        let teal = Color(red: 7 / 255, green: 62 / 255, blue: 67 / 255)
        let mint = Color(red: 132 / 255, green: 226 / 255, blue: 177 / 255)
        let project = projects.first { $0.id == active?.project }
        let customer = customers.first { $0.id == project?.customer }
        let activity = activities.first { $0.id == active?.activity }

        return VStack(alignment: .leading, spacing: 10) {
            if let customer {
                Text(customer.name)
                    .font(.caption)
                    .foregroundStyle(active == nil ? Color.secondary : Color.white.opacity(0.8))
            }

            Text(project?.name ?? (active == nil ? "Zeiterfassung" : "Unbekanntes Projekt"))
                .font(.headline)
            if let activity { Text(activity.name).font(.subheadline).opacity(0.8) }

            HStack {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if let active {
                        if let start = active.getBeginDate() {
                            Text(HomeState.duration(since: start, now: context.date))
                        } else {
                            Text("–:–").accessibilityLabel("Startzeit nicht verfügbar")
                        }
                    } else {
                        Text("00:00")
                    }
                }
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(active == nil ? Color.primary : mint)
                Spacer()
                if let active {
                    Button { stopTapped(active) } label: { Label("Stoppen", systemImage: "stop.fill") }
                        .buttonStyle(.borderedProminent)
                        .tint(mint)
                        .foregroundStyle(teal)
                } else {
                    Button(action: createTapped) { Label("Starten", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent)
                        .tint(.theme)
                        .foregroundStyle(Color.themeForeground)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(active == nil ? Color.primary : Color.white)
        .background(active == nil ? Color(uiColor: .secondarySystemGroupedBackground) : teal, in: RoundedRectangle(cornerRadius: 14))
    }
}
