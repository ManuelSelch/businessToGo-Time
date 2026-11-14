import SwiftUI
import CommonUI

struct AppHeader: View {
    
    let title: String
    var settingsTapped: () -> ()
    
    var body: some View {
        ZStack {
            HStack {
                Spacer()
                
                Text(title)
               
                Spacer()
            }
            .foregroundStyle(Color.themeForeground)
                
            HStack {
                Spacer()
                
                Button(action: settingsTapped){
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(Color.themeForeground)
                }
            }
                
        }
        .frame(height: 30)
        .padding()
        .background(Color.theme)
    }
}
