import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var selectedTab: SettingsTab
    
    var body: some View {
        Group {
            if selectedTab == .general {
                GeneralSettingsView(settings: settings)
            } else if selectedTab == .shortcuts {
                ShortcutsSettingsView(settings: settings)
            }
        }
        .frame(width: 500)
        #if os(macOS)
        .fixedSize(horizontal: true, vertical: true)
        #endif
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: AppSettings(), selectedTab: .constant(.general))
    }
}
