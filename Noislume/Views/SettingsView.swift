
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section("Cropping") {
                HStack {
                    Text("Initial crop inset:")
                    Slider(value: $settings.cropInsetPercentage, in: 1...20, step: 1)
                    Text("\(Int(settings.cropInsetPercentage))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}
