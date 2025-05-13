import SwiftUI

struct PositiveColorGradeControlsView: View {
    @ObservedObject var viewModel: InversionViewModel

    var body: some View {
        VStack {
            Text("Positive Color Grading")
                .font(.headline)
                .padding(.bottom, 2)

            // Positive Temperature Slider
            HStack {
                Text("Temperature (+)")
                Slider(
                    value: $viewModel.positiveTemperature,
                    in: 2000...50000,
                    step: 100,
                    onEditingChanged: { editing in
                        if !editing {
                            viewModel.triggerImageProcessing()
                        }
                    }
                )
                TextField("", value: $viewModel.positiveTemperature, formatter: NumberFormatter.integer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }

            // Positive Tint Slider
            HStack {
                Text("Tint (+)")
                Slider(
                    value: $viewModel.positiveTint,
                    in: -100...100,
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing {
                            viewModel.triggerImageProcessing()
                        }
                    }
                )
                TextField("", value: $viewModel.positiveTint, formatter: NumberFormatter.integer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }

            // Positive Vibrance Slider
            HStack {
                Text("Vibrance (+)")
                Slider(
                    value: $viewModel.positiveVibrance,
                    in: -1...1,
                    step: 0.01,
                    onEditingChanged: { editing in
                        if !editing {
                            viewModel.triggerImageProcessing()
                        }
                    }
                )
                TextField("", value: $viewModel.positiveVibrance, formatter: NumberFormatter.decimal(precision: 2))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }

            // Positive Saturation Slider
            HStack {
                Text("Saturation (+)")
                Slider(
                    value: $viewModel.positiveSaturation,
                    in: 0...2,
                    step: 0.01,
                    onEditingChanged: { editing in
                        if !editing {
                            viewModel.triggerImageProcessing()
                        }
                    }
                )
                TextField("", value: $viewModel.positiveSaturation, formatter: NumberFormatter.decimal(precision: 2))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
            }
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