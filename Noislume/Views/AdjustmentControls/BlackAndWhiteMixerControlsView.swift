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

            // Create a binding to the specific adjustment property
            let isBlackAndWhiteBinding = Binding<Bool>(
                get: { viewModel.currentAdjustments.isBlackAndWhite },
                set: { newValue in
                    var newAdjustments = viewModel.currentAdjustments
                    newAdjustments.isBlackAndWhite = newValue
                    viewModel.currentAdjustments = newAdjustments
                }
            )

            Toggle("Enable B&W", isOn: isBlackAndWhiteBinding)
                .padding(.horizontal)
                .onChange(of: viewModel.currentAdjustments.isBlackAndWhite) { oldValue, newValue in
                    if newValue == true && oldValue == false {
                        var newAdjustments = viewModel.currentAdjustments
                        // Reset to default contributions when B&W is enabled
                        newAdjustments.bwRedContribution = 0.299
                        newAdjustments.bwGreenContribution = 0.587
                        newAdjustments.bwBlueContribution = 0.114
                        viewModel.currentAdjustments = newAdjustments
                    }
                    // viewModel.objectWillChange.send() // Not strictly needed if currentAdjustments setter handles it
                    print("B&W Toggled: \(newValue)")
                }

            if viewModel.currentAdjustments.isBlackAndWhite {
                VStack {
                    AdjustmentSlider(
                        value: Binding(
                            get: { viewModel.currentAdjustments.bwRedContribution },
                            set: { val in
                                var newAdjustments = viewModel.currentAdjustments
                                newAdjustments.bwRedContribution = val
                                viewModel.currentAdjustments = newAdjustments
                            }
                        ),
                        title: "Red",
                        range: -1.0...2.0,
                        isDisabled: !viewModel.currentAdjustments.isBlackAndWhite,
                        onEditingChanged: nil
                    )

                    AdjustmentSlider(
                        value: Binding(
                            get: { viewModel.currentAdjustments.bwGreenContribution },
                            set: { val in
                                var newAdjustments = viewModel.currentAdjustments
                                newAdjustments.bwGreenContribution = val
                                viewModel.currentAdjustments = newAdjustments
                            }
                        ),
                        title: "Green",
                        range: -1.0...2.0,
                        isDisabled: !viewModel.currentAdjustments.isBlackAndWhite,
                        onEditingChanged: nil
                    )

                    AdjustmentSlider(
                        value: Binding(
                            get: { viewModel.currentAdjustments.bwBlueContribution },
                            set: { val in
                                var newAdjustments = viewModel.currentAdjustments
                                newAdjustments.bwBlueContribution = val
                                viewModel.currentAdjustments = newAdjustments
                            }
                        ),
                        title: "Blue",
                        range: -1.0...2.0,
                        isDisabled: !viewModel.currentAdjustments.isBlackAndWhite,
                        onEditingChanged: nil
                    )
                    
                    // Sepia Intensity Slider (can be part of B&W controls)
                    HStack {
                        Text("Sepia Tone")
                        Slider(
                            value: Binding(
                                get: { viewModel.currentAdjustments.sepiaIntensity },
                                set: { newValue in
                                    var newAdjustments = viewModel.currentAdjustments
                                    newAdjustments.sepiaIntensity = newValue
                                    viewModel.currentAdjustments = newAdjustments
                                }
                            ),
                            in: 0...1,
                            step: 0.01,
                            onEditingChanged: { editing in
                                // The binding for sepiaIntensity already triggers processing via currentAdjustments setter.
                                // No explicit call to processImage() is needed here.
                                // if !editing {
                                //     Task { await viewModel.processImage() } 
                                // }
                            }
                        )
                        TextField("", value: Binding(
                            get: { viewModel.currentAdjustments.sepiaIntensity },
                            set: { newValue in
                                var newAdjustments = viewModel.currentAdjustments
                                newAdjustments.sepiaIntensity = newValue
                                viewModel.currentAdjustments = newAdjustments
                            }
                        ), formatter: NumberFormatter.decimal(precision: 2))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                    }
                    .disabled(!viewModel.currentAdjustments.isBlackAndWhite)
                }
                .opacity(viewModel.currentAdjustments.isBlackAndWhite ? 1.0 : 0.5)
            }
        }
        .padding(.vertical)
    }
}

// Using the same NumberFormatter extension from PositiveColorGradeControlsView
// If it's global, this isn't needed here. For modularity, it can be repeated or moved.
// extension NumberFormatter { ... } // Assuming it's accessible 
