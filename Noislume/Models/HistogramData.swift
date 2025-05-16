import Foundation
import CoreImage

/// Represents the data for an RGB histogram.
struct HistogramData {
    /// Pixel counts for each intensity bin of the Red channel (typically 256 bins).
    let r: [Float]
    /// Pixel counts for each intensity bin of the Green channel.
    let g: [Float]
    /// Pixel counts for each intensity bin of the Blue channel.
    let b: [Float]
    // Optional: Add a luminance histogram if needed later
    // let l: [Float]?

    /// The number of bins in each channel's histogram (e.g., 256).
    var binCount: Int {
        // Assuming all channels have the same bin count
        return r.count
    }

    /// An empty state for the histogram data.
    static var empty: HistogramData {
        HistogramData(r: [], g: [], b: [])
    }

    /// Checks if the histogram data is empty.
    var isEmpty: Bool {
        r.isEmpty && g.isEmpty && b.isEmpty
    }
} 