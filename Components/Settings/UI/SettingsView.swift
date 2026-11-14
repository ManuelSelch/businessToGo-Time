import SwiftUI

public struct SettingsView: View {
    
    let integrationsTapped: () -> ()
    let debugTapped: () -> ()
    let introTapped: () -> ()
    let logoutTapped: () -> ()
    
    public init(integrationsTapped: @escaping () -> Void, debugTapped: @escaping () -> Void, introTapped: @escaping () -> Void, logoutTapped: @escaping () -> Void) {
        self.integrationsTapped = integrationsTapped
        self.debugTapped = debugTapped
        self.introTapped = introTapped
        self.logoutTapped = logoutTapped
    }
    
    public var body: some View {
        VStack {
            List {
                Button(action: integrationsTapped) { destinationLabel("Integrations") }
                Button(action: debugTapped) { destinationLabel("Debug") }
                Button(action: introTapped) { destinationLabel("Intro") }
                
                Button("Logout", action: { logoutTapped() })
                    .tint(Color.red)
                
            }
            .listStyle(.insetGrouped)
            .tint(Color.theme)
        }
        .navigationTitle("Settings")
    }

    private func destinationLabel(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

