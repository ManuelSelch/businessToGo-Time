import Foundation

@main
struct CustomerSearchTests {
    static func main() {
        precondition(CustomerSearch.matches(name: "Nord Studio", projectNames: ["Mobile App"], query: "  mObIlE  "))
        precondition(CustomerSearch.matches(name: "Nord Studio", projectNames: [], query: "nord"))
        precondition(CustomerSearch.matches(name: "Nord Studio", projectNames: [], query: "  "))
        precondition(!CustomerSearch.matches(name: "Nord Studio", projectNames: ["Website"], query: "mobile"))
        precondition(!CustomerSearch.includes(name: "Nord Studio", projectNames: ["Mobile"], teams: [1], selectedTeam: 2, query: "mobile"))
        precondition(CustomerSearch.includes(name: "Nord Studio", projectNames: ["Mobile"], teams: [1], selectedTeam: 1, query: "mobile"))
        precondition(!CustomerSearch.includes(name: "Nord Studio", projectNames: ["Mobile"], teams: [1], selectedTeam: 1, query: "website"))
        print("Customer search tests passed")
    }
}
