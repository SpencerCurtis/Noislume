import SwiftUI
import CoreImage

#if os(macOS)
import AppKit

struct FilmBaseCursorPreview: View {
    @ObservedObject var viewModel: InversionViewModel
    let cursorPosition: CGPoint
    let imageFrame: CGRect
    @State private var previewColor: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)?
    @State private var isVisible: Bool = false
    @State private var samplingTask: Task<Void, Never>?
    
    private let previewSize: CGFloat = 100
    private let colorSwatchSize: CGFloat = 40
    
    var body: some View {
        Group {
            if viewModel.isSamplingFilmBase {
                if isVisible, let color = previewColor {
                    colorPreviewContent(color: color)
                } else {
                    placeholderContent
                }
            }
        }
    }
    
    @ViewBuilder
    private func colorPreviewContent(color: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Color swatch
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                .frame(width: colorSwatchSize, height: colorSwatchSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            
            // RGB values
            VStack(alignment: .leading, spacing: 2) {
                Text("RGB Values:")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("R: \(Int(color.red * 255))")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text("G: \(Int(color.green * 255))")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text("B: \(Int(color.blue * 255))")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
        )
        .position(adjustedPosition)
        .animation(.easeOut(duration: 0.05), value: cursorPosition)
        .onAppear {
            updatePreviewColor()
        }
        .onChange(of: cursorPosition) { _, _ in
            updatePreviewColor()
        }
        .onDisappear {
            samplingTask?.cancel()
        }
    }
    
    @ViewBuilder
    private var placeholderContent: some View {
        if !imageFrame.contains(cursorPosition) && cursorPosition != .zero {
            Text("Move cursor over image to preview colors")
                .font(.caption)
                .foregroundColor(.white)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                )
                .position(x: cursorPosition.x, y: max(50, min(cursorPosition.y, imageFrame.minY - 30)))
                .onAppear {
                    updatePreviewColor()
                }
                .onChange(of: cursorPosition) { _, _ in
                    updatePreviewColor()
                }
        } else {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    updatePreviewColor()
                }
                .onChange(of: cursorPosition) { _, _ in
                    updatePreviewColor()
                }
                .onDisappear {
                    samplingTask?.cancel()
                }
        }
    }
    
    /// Adjusts the preview position to keep it visible on screen and well offset from cursor
    private var adjustedPosition: CGPoint {
        let offset: CGFloat = 60 // Increased offset to keep preview away from cursor
        let padding: CGFloat = 10 // Padding from screen edges
        
        // Start with default position (bottom-right of cursor)
        var x = cursorPosition.x + offset
        var y = cursorPosition.y + offset
        
        // Get the bounds we need to work within (with padding)
        let minX = imageFrame.minX + padding
        let maxX = imageFrame.maxX - previewSize - padding
        let minY = imageFrame.minY + padding
        let maxY = imageFrame.maxY - previewSize - padding
        
        // Try different positions to avoid getting in the way of the cursor
        // Priority: bottom-right, bottom-left, top-right, top-left
        
        // Check if bottom-right position fits
        if x <= maxX && y <= maxY {
            // Good to go with bottom-right
        }
        // Try bottom-left
        else if cursorPosition.x - offset - previewSize >= minX && y <= maxY {
            x = cursorPosition.x - offset - previewSize
        }
        // Try top-right  
        else if x <= maxX && cursorPosition.y - offset - previewSize >= minY {
            y = cursorPosition.y - offset - previewSize
        }
        // Try top-left
        else if cursorPosition.x - offset - previewSize >= minX && cursorPosition.y - offset - previewSize >= minY {
            x = cursorPosition.x - offset - previewSize
            y = cursorPosition.y - offset - previewSize
        }
        // Fallback: clamp to bounds
        else {
            x = max(minX, min(x, maxX))
            y = max(minY, min(y, maxY))
        }
        
        return CGPoint(x: x, y: y)
    }
    
    /// Updates the preview color by sampling at the current cursor position
    private func updatePreviewColor() {
        guard viewModel.isSamplingFilmBase,
              imageFrame.contains(cursorPosition) else {
            isVisible = false
            samplingTask?.cancel()
            return
        }
        
        isVisible = true
        
        // Don't cancel previous task - let multiple sampling tasks run concurrently for responsiveness
        // The UI will update with the latest completed sample
        
        // Create a new sampling task that runs immediately
        let currentPosition = cursorPosition // Capture current position
        samplingTask = Task {
            // Sample immediately without delay for real-time responsiveness
            let sampledColor = await viewModel.sampleColorForPreview(at: currentPosition, imageFrame: imageFrame)
            
            await MainActor.run {
                // Always update with the latest sample, regardless of task cancellation
                // This ensures we get real-time updates during cursor movement
                if let color = sampledColor {
                    previewColor = color
                } else {
                    isVisible = false
                }
            }
        }
    }
}

#endif 