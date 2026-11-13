import SwiftUI

import KimaiCore

struct ReportSummaryView: View {
    let timesheets: [KimaiTimesheet]
    
    var totalTime: String {
        var time: TimeInterval = 0
        for timesheet in timesheets {
            time += timesheet.calculateDuration() ?? 0
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: time) ?? "--"
    }
    
    var totalRate: String {
        var rate: Double = 0
        for timesheet in timesheets {
            rate += timesheet.rate
        }
        return String(format: "%.02f€", rate)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Zeit")
                    .foregroundStyle(Color.textHeaderSecondary)
                    .font(.system(.subheadline))
                Text(totalTime)
                    .font(.headline.monospacedDigit())
            }
            
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text("Einnahmen")
                    .foregroundStyle(Color.textHeaderSecondary)
                    .font(.system(.subheadline))
                Text("\(totalRate)")
                    .font(.headline.monospacedDigit())
            }
            
        }
    }
}

#Preview {
    ReportSummaryView(timesheets: [])
}
