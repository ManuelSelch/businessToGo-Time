import SwiftUI

import KimaiCore
import CommonUI

public struct KimaiCustomerSheet: View {
    let customer: KimaiCustomer
    let teams: [KimaiTeam]
    
    let saveTapped: (KimaiCustomer) -> ()
    let cancelTapped: () -> Void
    
    var selectedTeams: [KimaiTeam] {
        return teams.filter { customer.teams.contains($0.id) }
    }
    
    @State var name = ""
    @State var color: String?
    
    public init(customer: KimaiCustomer, teams: [KimaiTeam], saveTapped: @escaping (KimaiCustomer) -> Void, cancelTapped: @escaping () -> Void) {
        self.customer = customer
        self.teams = teams
        self.saveTapped = saveTapped
        self.cancelTapped = cancelTapped
    }
    
    public var body: some View {
        VStack {
            List {
                HStack {
                    Text("Name: ")
                    Spacer()
                    TextField("", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
                
                HStack {
                    Text("Farbe: ")
                    Spacer()
                    CustomColorPicker(selectedColor: $color)
                }
                
                
                if customer.id != KimaiCustomer.new.id {
                    HStack {
                        Text("Teams: ")
                        Spacer()

                        ForEach(selectedTeams, id: \.id) { team in
                            Text(team.name).foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                }
                
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen", action: cancelTapped)
                }
                ToolbarItem(placement: .topBarTrailing){
                    Button(action: {
                        var customer = customer
                        customer.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        customer.color = color ?? ""
                        saveTapped(customer)
                    }){
                        let isCreate = (customer.id == KimaiCustomer.new.id)
                        let label = isCreate ? "Create" : "Save"
                        Text(label)
                            .foregroundStyle(Color.theme)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            .onAppear {
                name = customer.name
                color = customer.color
            }
        }
    }
}
