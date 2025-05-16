import SwiftUI

struct BlackAndWhiteMixerControlsView: View {
    @ObservedObject var viewModel: InversionViewModel

    // To provide a more intuitive user experience for sliders,
    // we can normalize the sum of contributions. However, for direct control,
    // we'll let users set them independently for now. They can sum to > 1 or < 1.
    // A more advanced implementation might include normalization options or presets.

    var body: some View {
        VStack {
            Text("B&W Channel Mixer")
                .font(.headline)
                .padding(.bottom, 2)

            // isBlackAndWhite Toggle
            HStack {
                Text("B&W Mixer")
                Spacer()
                Toggle("Enable B&W", isOn: $viewModel.isBlackAndWhite)
                    .labelsHidden()
                    .onChange(of: viewModel.isBlackAndWhite) { oldValue, newValue in
                        // If B&W mode is toggled, reset individual color adjustments to avoid
                        // unexpected carry-over effects if the user toggles B&W off and on.
                        if newValue == true && oldValue == false {
                            viewModel.currentAdjustments.bwRedContribution = 0.299
                            viewModel.currentAdjustments.bwGreenContribution = 0.587
                            viewModel.currentAdjustments.bwBlueContribution = 0.114
                        }
                        viewModel.objectWillChange.send() // Ensure UI updates
                    }
            }
            .padding(.horizontal)

            Group {
                // Red Contribution Slider
                HStack {
                    Text("Red Channel")
                        .foregroundColor(Color.red)
                    Slider(
                        value: $viewModel.bwRedContribution,
                        in: -1.0...2.0, // Allow negative contributions for effects, and >1 for emphasis
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                viewModel.triggerImageProcessing()
                            }
                        }
                    )
                    TextField("", value: $viewModel.bwRedContribution, formatter: NumberFormatter.decimal(precision: 2))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                }

                // Green Contribution Slider
                HStack {
                    Text("Green Channel")
                        .foregroundColor(Color.green)
                    Slider(
                        value: $viewModel.bwGreenContribution,
                        in: -1.0...2.0,
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                viewModel.triggerImageProcessing()
                            }
                        }
                    )
                    TextField("", value: $viewModel.bwGreenContribution, formatter: NumberFormatter.decimal(precision: 2))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                }

                // Blue Contribution Slider
                HStack {
                    Text("Blue Channel")
                        .foregroundColor(Color.blue)
                    Slider(
                        value: $viewModel.bwBlueContribution,
                        in: -1.0...2.0,
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                viewModel.triggerImageProcessing()
                            }
                        }
                    )
                    TextField("", value: $viewModel.bwBlueContribution, formatter: NumberFormatter.decimal(precision: 2))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                }
                
                // Sepia Intensity Slider (can be part of B&W controls)
                HStack {
                    Text("Sepia Tone")
                    Slider(
                        value: $viewModel.sepiaIntensity,
                        in: 0...1,
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                viewModel.triggerImageProcessing()
                            }
                        }
                    )
                    TextField("", value: $viewModel.sepiaIntensity, formatter: NumberFormatter.decimal(precision: 2))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                }
            }
            .disabled(!viewModel.isBlackAndWhite) // Disable sliders if B&W is not active
            .opacity(viewModel.isBlackAndWhite ? 1.0 : 0.5) // Visually indicate disabled state
        }
        .padding(.vertical)
    }
}

// Using the same NumberFormatter extension from PositiveColorGradeControlsView
// If it's global, this isn't needed here. For modularity, it can be repeated or moved.
// extension NumberFormatter { ... } // Assuming it's accessible 
