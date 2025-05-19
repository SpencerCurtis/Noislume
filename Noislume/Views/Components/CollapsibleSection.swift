import SwiftUI

struct CollapsibleSection<Content: View>: View {
    @ObservedObject private var appSettings = AppSettings.shared
    let sectionKey: String
    @State private var isLocallyExpanded: Bool
    
    let title: String
    let content: () -> Content
    let resetAction: (() -> Void)? // Optional closure for the reset action
    
    init(sectionKey: String, title: String, defaultExpanded: Bool = true, resetAction: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.sectionKey = sectionKey
        self.title = title
        self.content = content
        self.resetAction = resetAction
        // Initialize the state from AppSettings
        self._isLocallyExpanded = State(initialValue: AppSettings.shared.isSidebarSectionExpanded(forKey: sectionKey, defaultState: defaultExpanded))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack { // Main HStack for title and expand button
                // Reset button on the left, if action is provided
                if let action = resetAction {
                    Button(action: action) {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4) // Add a little spacing
                }
                
                // Existing clickable area for expand/collapse
                Button {
                    withAnimation {
                        isLocallyExpanded.toggle()
                        appSettings.setSidebarSectionState(forKey: sectionKey, isExpanded: isLocallyExpanded)
                    }
                } label: {
                    HStack {
                        Text(title)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isLocallyExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle()) // Make the whole HStack clickable
                }
                .buttonStyle(.plain)
            }
            
            if isLocallyExpanded {
                content()
                    .transition(.opacity)
                    .padding(.vertical)
            }
        }
    }
}
