
import SwiftUI

struct CollapsibleSection: View {
    let title: String
    @Binding var isExpanded: Bool
    let content: () -> any View
    
    var body: some View {
        VStack(alignment: .leading) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                AnyView(content())
                    .transition(.opacity)
            }
        }
    }
}
