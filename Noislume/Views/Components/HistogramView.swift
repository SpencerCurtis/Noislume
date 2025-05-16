import SwiftUI
import CoreGraphics

struct HistogramView: View {
    let histogramData: HistogramData?
    var title: String = "Histogram"

    private let maxBarHeight: CGFloat = 100 // Max height for a histogram bar area
    private let barSpacing: CGFloat = 0.5

    var body: some View {
        VStack(alignment: .leading) {
            if let data = histogramData, !data.isEmpty {
                Canvas {
                    context, size in
                    
                    guard data.binCount > 0 else { return }

                    let barWidth = max(0, (size.width - (CGFloat(data.binCount - 1) * barSpacing)) / CGFloat(data.binCount))
                    
                    // Find the overall peak value across all channels (R, G, B, and L if present) for normalization
                    let maxR = data.r.max() ?? 0
                    let maxG = data.g.max() ?? 0
                    let maxB = data.b.max() ?? 0
                    let maxL = data.l?.max() ?? 0 // Consider luminance for overall max
                    let overallMax = max(maxR, maxG, maxB, maxL)
                    
                    guard overallMax > 0 else { return } // Avoid division by zero

                    // Draw background guides (e.g., at 25%, 50%, 75% height)
                    let guideY25 = size.height * 0.25
                    let guideY50 = size.height * 0.50
                    let guideY75 = size.height * 0.75

                    context.stroke(Path { path in
                        path.move(to: CGPoint(x: 0, y: guideY25))
                        path.addLine(to: CGPoint(x: size.width, y: guideY25))
                        path.move(to: CGPoint(x: 0, y: guideY50))
                        path.addLine(to: CGPoint(x: size.width, y: guideY50))
                        path.move(to: CGPoint(x: 0, y: guideY75))
                        path.addLine(to: CGPoint(x: size.width, y: guideY75))
                    }, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)

                    // Draw Luminance channel (if available) first, as a backdrop
                    if let lData = data.l, !lData.isEmpty {
                        var pathL = Path()
                        for i in 0..<data.binCount {
                            let barHeight = (lData[i] / overallMax) * Float(maxBarHeight)
                            let xPos = CGFloat(i) * (barWidth + barSpacing)
                            let yPos = size.height - CGFloat(barHeight)
                            pathL.addRect(CGRect(x: xPos, y: yPos, width: barWidth, height: CGFloat(barHeight)))
                        }
                        context.fill(pathL, with: .color(Color.gray.opacity(0.4))) // Slightly less opaque for backdrop
                    }

                    // Draw Red channel
                    var pathR = Path()
                    for i in 0..<data.binCount {
                        let barHeight = (data.r[i] / overallMax) * Float(maxBarHeight)
                        let xPos = CGFloat(i) * (barWidth + barSpacing)
                        let yPos = size.height - CGFloat(barHeight)
                        pathR.addRect(CGRect(x: xPos, y: yPos, width: barWidth, height: CGFloat(barHeight)))
                    }
                    context.fill(pathR, with: .color(Color.red.opacity(0.7))) // Slightly more opaque

                    // Draw Green channel
                    var pathG = Path()
                    for i in 0..<data.binCount {
                        let barHeight = (data.g[i] / overallMax) * Float(maxBarHeight)
                        let xPos = CGFloat(i) * (barWidth + barSpacing)
                        let yPos = size.height - CGFloat(barHeight)
                        pathG.addRect(CGRect(x: xPos, y: yPos, width: barWidth, height: CGFloat(barHeight)))
                    }
                    context.blendMode = .screen // Use screen blend mode for G & B over R & L
                    context.fill(pathG, with: .color(Color.green.opacity(0.7)))

                    // Draw Blue channel
                    var pathB = Path()
                    for i in 0..<data.binCount {
                        let barHeight = (data.b[i] / overallMax) * Float(maxBarHeight)
                        let xPos = CGFloat(i) * (barWidth + barSpacing)
                        let yPos = size.height - CGFloat(barHeight)
                        pathB.addRect(CGRect(x: xPos, y: yPos, width: barWidth, height: CGFloat(barHeight)))
                    }
                    // context.blendMode = .screen // Already set
                    context.fill(pathB, with: .color(Color.blue.opacity(0.7)))
                    
                    context.blendMode = .normal // Reset blend mode

                    // Draw border around the canvas
                    let borderRect = CGRect(origin: .zero, size: size)
                    context.stroke(Path(borderRect), with: .color(.gray.opacity(0.5)), lineWidth: 1)

                }
                .frame(height: maxBarHeight)
                .background(Color.black.opacity(0.1))
                .padding(-1)
                
            } else {
                Text("Histogram data not available.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(height: maxBarHeight)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(4)
            }
        }
    }
}

struct HistogramView_Previews: PreviewProvider {
    static var previews: some View {
        // Example with some dummy data
        let dummyR = (0..<256).map { _ in Float.random(in: 0...1000) }
        let dummyG = (0..<256).map { _ in Float.random(in: 0...800) }
        let dummyB = (0..<256).map { _ in Float.random(in: 0...600) }
        let data = HistogramData(r: dummyR, g: dummyG, b: dummyB, l: [100])
        
        let dummyL = (0..<256).map { i in (dummyR[i] + dummyG[i] + dummyB[i]) / 3 } // Simple L approx
        let dataWithL = HistogramData(r: dummyR, g: dummyG, b: dummyB, l: dummyL)
        
        let emptyData: HistogramData? = nil

        VStack {
            Text("RGB Histogram")
            HistogramView(histogramData: data)
                .padding()
            
            Text("RGB + Luminance Histogram")
            HistogramView(histogramData: dataWithL)
                .padding()
            
            HistogramView(histogramData: emptyData, title: "Empty Histogram")
                .padding()
            
            HistogramView(histogramData: HistogramData.empty, title: "Truly Empty Histogram")
                .padding()
        }
        .frame(width: 300)
    }
} 
