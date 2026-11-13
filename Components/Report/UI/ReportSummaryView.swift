import SwiftUI

import KimaiCore

struct ReportSummaryView: View {
    let timesheets: [KimaiTimesheet]
    var cachedTotals: (duration: TimeInterval, rate: Double)? = nil
    
    var totalTime: String {
        var time: TimeInterval = 0
        if let cachedTotals = cachedTotals {
            time = cachedTotals.duration
        } else {
            for timesheet in timesheets {
                time += timesheet.calculateDuration() ?? 0
            }
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: time) ?? "--"
    }
    
    var totalRate: String {
        var rate: Double = 0
        if let cachedTotals = cachedTotals {
            rate = cachedTotals.rate
        } else {
            for timesheet in timesheets {
                rate += timesheet.rate
            }
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
