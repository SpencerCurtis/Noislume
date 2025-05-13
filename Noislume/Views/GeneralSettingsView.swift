import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    // Formatter for the cache size limit TextField
    private var cacheSizeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1 // Minimum cache size 1MB
        formatter.maximum = 10000 // Maximum cache size 10GB (adjust as needed)
        formatter.allowsFloats = false
        return formatter
    }()
    
    init(settings: AppSettings) {
        self.settings = settings
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cropping")
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Initial crop inset:")
                    // Revert back to Slider
                    Slider(value: $settings.cropInsetPercentage, in: 0...50, step: 1)
                    Text("\(Int(settings.cropInsetPercentage))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                Toggle("Show original when cropping", isOn: $settings.showOriginalWhenCropping)
            }
            .padding(.leading)

            Divider()

            Text("Caching")
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable thumbnail file cache", isOn: $settings.enableThumbnailFileCache)

                if settings.enableThumbnailFileCache {
                    HStack {
                        Text("Cache size limit (MB):")
                        TextField(
                            "", 
                            value: $settings.thumbnailCacheSizeLimitMB, 
                            formatter: cacheSizeFormatter
                        )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        Stepper(
                            "", 
                            value: $settings.thumbnailCacheSizeLimitMB, 
                            in: 1...10000, // Match formatter range
                            step: 100 // Step by 100MB
                        )
                        .labelsHidden()
                    }
                    .padding(.leading) // Indent the size limit setting
                    .disabled(!settings.enableThumbnailFileCache) // Also disable if toggle is off
                }
            }
            .padding(.leading)
        }
        .padding()
    }
} 