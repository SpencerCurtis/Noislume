import SwiftUI

struct DarkButtonStyle: ButtonStyle {
    let isRecording: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isRecording ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
} 