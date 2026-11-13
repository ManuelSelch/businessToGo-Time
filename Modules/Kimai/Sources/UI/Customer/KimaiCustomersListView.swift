import SwiftUI

import CommonUI
import KimaiCore

public struct KimaiCustomersListView: View {
    let customers: [KimaiCustomer]
    let projects: [KimaiProject]
    @Binding var search: String
    @State private var expandedCustomers: Set<Int> = []
    let hasFilters: Bool
    let resetFilters: () -> Void
    let customerEditTapped: (KimaiCustomer) -> Void
    let customerDeleteTapped: (KimaiCustomer) -> Void
    let customerCreated: () -> Void
    let projectTapped: (KimaiProject) -> Void
    let projectEditTapped: (KimaiProject) -> Void
    let projectDeleteTapped: (KimaiProject) -> Void
    let projectCreated: (KimaiCustomer) -> Void

    public init(
        customers: [KimaiCustomer], projects: [KimaiProject], search: Binding<String>, hasFilters: Bool,
        resetFilters: @escaping () -> Void,
        customerEditTapped: @escaping (KimaiCustomer) -> Void,
        customerDeleteTapped: @escaping (KimaiCustomer) -> Void,
        customerCreated: @escaping () -> Void,
        projectTapped: @escaping (KimaiProject) -> Void,
        projectEditTapped: @escaping (KimaiProject) -> Void,
        projectDeleteTapped: @escaping (KimaiProject) -> Void,
        projectCreated: @escaping (KimaiCustomer) -> Void
    ) {
        self.customers = customers
        self.projects = projects
        self._search = search
        self.hasFilters = hasFilters
        self.resetFilters = resetFilters
        self.customerEditTapped = customerEditTapped
        self.customerDeleteTapped = customerDeleteTapped
        self.customerCreated = customerCreated
        self.projectTapped = projectTapped
        self.projectEditTapped = projectEditTapped
        self.projectDeleteTapped = projectDeleteTapped
        self.projectCreated = projectCreated
    }

    private func folderColor(_ value: String?) -> Color {
        guard let value, !value.isEmpty else { return .secondary }
        return Color(hex: value)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Kunden oder Projekte suchen", text: $search)
                        .accessibilityLabel("Kunden oder Projekte suchen")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel("Suche löschen")
                    }
                }
                .padding(ControlSpacing.compact)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                Button(action: customerCreated) { Image(systemName: "plus") }
                    .foregroundStyle(Color.primary)
                    .accessibilityLabel("Neuen Kunden erstellen")
            }
            .padding(.horizontal, ControlSpacing.standard)

            List {
                if customers.isEmpty {
                    VStack(alignment: .leading, spacing: ControlSpacing.compact) {
                        Text(hasFilters ? "Keine passenden Kunden" : "Noch keine Kunden")
                        if hasFilters { Button("Filter zurücksetzen", action: resetFilters) }
                    }
                }
                ForEach(customers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { customer in
                    let customerProjects = projects.filter {
                        $0.customer == customer.id && CustomerSearch.projectMatches(customerName: customer.name, projectName: $0.name, query: search)
                    }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    let isSearching = !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let expanded = isSearching || expandedCustomers.contains(customer.id)
                    Section {
                        HStack(spacing: 0) {
                            Button {
                                if expandedCustomers.contains(customer.id) {
                                    expandedCustomers.remove(customer.id)
                                } else {
                                    expandedCustomers.insert(customer.id)
                                }
                            } label: {
                                HStack {
                                    FolderRow(title: customer.name, color: folderColor(customer.color), showsChevron: false, minHeight: 44)
                                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(expanded ? "Aufgeklappt" : "Zugeklappt")
                            Button { projectCreated(customer) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.primary)
                                .accessibilityLabel("Projekt für \(customer.name) erstellen")
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                        .listRowBackground(CustomerGroupBackground(top: true, bottom: !expanded || customerProjects.isEmpty))
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) { customerDeleteTapped(customer) }
                            Button("Edit") { customerEditTapped(customer) }.tint(.gray)
                        }
                        ForEach(expanded ? customerProjects : []) { project in
                            Button { projectTapped(project) } label: {
                                FolderRow(title: project.name, color: folderColor(project.color), minHeight: 44)
                                    .padding(.leading, 16)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                            .listRowBackground(CustomerGroupBackground(top: false, bottom: project.id == customerProjects.last?.id))
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { projectDeleteTapped(project) }
                                Button("Edit") { projectEditTapped(project) }.tint(.gray)
                            }
                        }
                    }
                }
            }
            .padding(.top, 12)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .modifier(CompactSectionSpacing())
            .environment(\.defaultMinListHeaderHeight, 0)
            .environment(\.defaultMinListRowHeight, 44)
        }
    }
}

private struct CustomerGroupBackground: View {
    let top: Bool
    let bottom: Bool

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.homeCard)
                .frame(height: geometry.size.height + (top ? 0 : 14) + (bottom ? 0 : 14))
                .offset(y: top ? 0 : -14)
        }
        .clipped()
        .padding(.horizontal, 16)
    }
}

private struct CompactSectionSpacing: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17, macOS 14, *) {
            content.listSectionSpacing(8)
        } else {
            content
        }
    }
}
