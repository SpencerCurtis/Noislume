
import SwiftUI

struct CollapsibleSection<Content: View>: View {
    
    @Binding var isExpanded: Bool
    
    let title: String
    let content: () -> Content
    
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
                content()
                    .transition(.opacity)
                    .padding(.vertical)
            }
        }
    }
}
