import SwiftUI

import CommonUI
import KimaiCore

public struct KimaiCustomersListView: View {
    let customers: [KimaiCustomer]
    @Binding var search: String
    let hasFilters: Bool
    let resetFilters: () -> Void
    let customerTapped: (Int) -> Void
    let customerEditTapped: (KimaiCustomer) -> Void
    let customerDeleteTapped: (KimaiCustomer) -> Void
    let customerCreated: () -> Void

    public init(
        customers: [KimaiCustomer], search: Binding<String>, hasFilters: Bool,
        resetFilters: @escaping () -> Void,
        customerTapped: @escaping (Int) -> Void,
        customerEditTapped: @escaping (KimaiCustomer) -> Void,
        customerDeleteTapped: @escaping (KimaiCustomer) -> Void,
        customerCreated: @escaping () -> Void
    ) {
        self.customers = customers
        self._search = search
        self.hasFilters = hasFilters
        self.resetFilters = resetFilters
        self.customerTapped = customerTapped
        self.customerEditTapped = customerEditTapped
        self.customerDeleteTapped = customerDeleteTapped
        self.customerCreated = customerCreated
    }

    public var body: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, ControlSpacing.standard)

            List {
                Section {
                    if customers.isEmpty {
                        VStack(alignment: .leading, spacing: ControlSpacing.compact) {
                            Text(hasFilters ? "Keine passenden Kunden" : "Noch keine Kunden")
                            if hasFilters { Button("Filter zurücksetzen", action: resetFilters) }
                        }
                        .padding(.vertical, ControlSpacing.compact)
                    }
                    ForEach(customers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { customer in
                        KimaiCustomerCard(customer: customer, customerTapped: { customerTapped(customer.id) })
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { customerDeleteTapped(customer) }
                                Button("Edit") { customerEditTapped(customer) }.tint(.gray)
                            }
                    }
                } header: {
                    HStack {
                        Text("Kunden")
                        Spacer()
                        Button(action: customerCreated) { Image(systemName: "plus") }
                            .buttonStyle(IconButtonStyle())
                            .accessibilityLabel("Neuen Kunden erstellen")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}
