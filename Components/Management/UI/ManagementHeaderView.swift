import SwiftUI

import CommonUI
import KimaiCore
import IntegrationCore

struct ManagementHeaderView: View {
    let route: ManagementComponent.Route

    var projects: [KimaiProject]
    var syncStatus: SyncStatus

    let syncTapped: () -> ()
    let projectTapped: (Integration) -> ()
    let playTapped: (KimaiTimesheet) -> ()
    let settingsTapped: () -> ()
    
    init(
        route: ManagementComponent.Route,
        projects: [KimaiProject],
        syncStatus: SyncStatus,
        
        syncTapped: @escaping () -> Void,
        projectTapped: @escaping (Integration) -> Void,
        playTapped: @escaping (KimaiTimesheet) -> Void,
        settingsTapped: @escaping () -> ()
    ) {
        self.route = route
        self.projects = projects
        self.syncStatus = syncStatus
        
        self.syncTapped = syncTapped
        self.projectTapped = projectTapped
        self.playTapped = playTapped
        self.settingsTapped = settingsTapped
    }
    
    var body: some View {
        HStack(spacing: 0) {
            switch(route) {
            case .assistant, .kimai(.activitySheet), .kimai(.customerSheet), .kimai(.projectSheet), .kimai(.timesheetSheet):
                EmptyView()
            default:
                switch(syncStatus) {
                case .idle:
                    Button(action: syncTapped){
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Synchronisieren")
                case .syncing:
                    ProgressView()
                case .failed:
                    Button(action: syncTapped){
                        Image(systemName: "exclamationmark.icloud.fill")
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Synchronisierung fehlgeschlagen, erneut versuchen")
                    .foregroundStyle(Color.red)
                }
              
                Button(action: {
                    switch(route){
                    case let .kimai(.projectsList(customer)):
                        let project = projects.first { $0.customer == customer}
                        var timesheet = KimaiTimesheet.new
                        timesheet.project = project?.id ?? 0
                        playTapped(timesheet)
   
                    case let .kimai(.projectDetail(projectId)):
                        let project = projects.first { $0.id == projectId}
                        var timesheet = KimaiTimesheet.new
                        timesheet.project = project?.id ?? 0
                        playTapped(timesheet)
                        
                    default:
                        playTapped(KimaiTimesheet.new)
                    }
                    
                }){
                    Image(systemName: "play.fill")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Zeiteintrag erstellen")
                
                Button(action: settingsTapped) {
                    Image(systemName: "gear")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Einstellungen")
            }
      
            
        }
        .font(.system(size: 15))
        .foregroundColor(Color.theme)
    }
}
