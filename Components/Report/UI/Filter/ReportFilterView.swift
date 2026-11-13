import SwiftUI
import CommonUI
import KimaiCore

struct ReportFilterView: View {
    let customers: [KimaiCustomer]
    let projects: [KimaiProject]
    let teams: [KimaiTeam]
    let apply: (Int?, Int?, Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var customer: Int?
    @State private var project: Int?
    @State private var team: Int?

    init(customers: [KimaiCustomer], projects: [KimaiProject], teams: [KimaiTeam], customer: Int?, project: Int?, team: Int?, apply: @escaping (Int?, Int?, Int?) -> Void) {
        self.customers = customers
        self.projects = projects
        self.teams = teams
        self.apply = apply
        _customer = State(initialValue: customer)
        _project = State(initialValue: project)
        _team = State(initialValue: team)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kunde", selection: $customer) {
                        Text("Alle Kunden").tag(Int?.none)
                        ForEach(customers, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .onChange(of: customer) { selectedCustomer in
                        if let project, !projects.contains(where: { $0.id == project && (selectedCustomer == nil || $0.customer == selectedCustomer) }) {
                            self.project = nil
                        }
                    }
                    Picker("Projekt", selection: $project) {
                        Text("Alle Projekte").tag(Int?.none)
                        ForEach(projects.filter { customer == nil || $0.customer == customer }, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Team", selection: $team) {
                        Text("Alle Teams").tag(Int?.none)
                        ForEach(teams, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                Button("Filter zurücksetzen") { customer = nil; project = nil; team = nil }
                    .foregroundStyle(Color.theme)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { apply(customer, project, team); dismiss() } }
            }
        }
    }
}
