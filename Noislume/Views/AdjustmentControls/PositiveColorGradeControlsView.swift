import SwiftUI

struct PositiveColorGradeControlsView: View {
    @ObservedObject var viewModel: InversionViewModel

    var body: some View {
        VStack {
            Text("Positive Color Grading")
                .font(.headline)
                .padding(.bottom, 2)

            // White Balance Picker Button
            HStack {
                Button {
                    if viewModel.isSamplingWhiteBalance {
                        viewModel.isSamplingWhiteBalance = false
                    } else {
                        // If starting sampling, ensure other sampling modes are off.
                        viewModel.isSamplingFilmBaseColor = false
                        viewModel.isSamplingWhiteBalance = true
                    }
                } label: {
                    Label(viewModel.isSamplingWhiteBalance ? "Cancel" : "Pick White Balance", systemImage: "eyedropper")
                }
                #if os(macOS)
                .help(viewModel.isSamplingWhiteBalance ? "Cancel white balance sampling" : "Click to sample a neutral color from the image for white balance")
                #endif
                Spacer() // Push button to the left if desired
            }
            .padding(.bottom, 5)
            
            if viewModel.isSamplingWhiteBalance {
                Text("Click on a neutral (white or gray) area in the image.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Positive Temperature Slider
            HStack {
                Text("Temperature (+)")
                Slider(
                    value: $viewModel.currentAdjustments.positiveTemperature,
                    in: 2000...50000,
                    step: 100
                )
                TextField("", value: $viewModel.currentAdjustments.positiveTemperature, formatter: NumberFormatter.integer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }

            // Positive Tint Slider
            HStack {
                Text("Tint (+)")
                Slider(
                    value: $viewModel.currentAdjustments.positiveTint,
                    in: -100...100,
                    step: 1
                )
                TextField("", value: $viewModel.currentAdjustments.positiveTint, formatter: NumberFormatter.integer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }

            // Positive Vibrance Slider
            HStack {
                Text("Vibrance (+)")
                Slider(
                    value: $viewModel.currentAdjustments.positiveVibrance,
                    in: -1...1,
                    step: 0.01
                )
                TextField("", value: $viewModel.currentAdjustments.positiveVibrance, formatter: NumberFormatter.decimal(precision: 2))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }

            // Positive Saturation Slider
            HStack {
                Text("Saturation (+)")
                Slider(
                    value: $viewModel.currentAdjustments.positiveSaturation,
                    in: 0...2,
                    step: 0.01
                )
                TextField("", value: $viewModel.currentAdjustments.positiveSaturation, formatter: NumberFormatter.decimal(precision: 2))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }
            
            // Add DisclosureGroup for Polynomial Controls
            DisclosureGroup("Polynomial Curve Coefficients (Advanced)") {
                PolynomialControlsView(viewModel: viewModel)
                    .padding(.top, 5) // Add some spacing above the polynomial controls
            }
            .padding(.top, 10) // Add some spacing above the disclosure group

        }
        .padding(.vertical)
    }
}

// Extension for NumberFormatters (if not already available globally)
// You might already have this or a similar utility. If so, this can be omitted.
extension NumberFormatter {
    static var integer: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    static func decimal(precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        return formatter
    }
} 