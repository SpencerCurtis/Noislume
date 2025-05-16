import SwiftUI

struct V2EditingControls: View {
    @ObservedObject var viewModel: InversionViewModel
    // Add any @State variables needed for V2 controls here

    // State for collapsible sections
    @State private var isFilmBaseExpanded = true
    @State private var isAutoLevelsExpanded = true
    @State private var isExposureContrastExpanded = true
    @State private var isPerceptualToneMapExpanded = true
    @State private var isColorCastRefinementExpanded = true // New state for new section
    @State private var isGeometryExpanded = true // New state for Geometry section

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Processing V2 Controls")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Film Base Neutralization Section (existing)
            CollapsibleSection(isExpanded: $isFilmBaseExpanded, title: "Film Base Neutralization") {
                VStack {
                    Button(action: {
                        viewModel.isSamplingFilmBaseColor.toggle()
                    }) {
                        Label(viewModel.isSamplingFilmBaseColor ? "Sampling... (Tap Image)" : "Sample Film Base Color", systemImage: "eyedropper")
                    }
                    .help("Sample a point on the image that should be neutral (e.g., unexposed film base between frames). This color will be used to neutralize the film base tint.")
                    
                    if let sampledColor = viewModel.currentAdjustments.filmBaseSamplePointColor {
                        HStack {
                            Text("Selected Base Color:")
                            Rectangle()
                                .fill(Color(red: sampledColor.red, green: sampledColor.green, blue: sampledColor.blue, opacity: sampledColor.alpha))
                                .frame(width: 20, height: 20)
                                .border(Color.gray)
                            Button(action: {
                                viewModel.clearFilmBaseSample()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }.padding(.top, 5)
                    }
                }
                .padding(.vertical, 5)
            }
            
            // Auto Levels Channel Normalization (existing controls, if any - placeholder)
            CollapsibleSection(isExpanded: $isAutoLevelsExpanded, title: "Auto Levels Normalization") {
                // Currently, this filter is fully automatic based on histogram.
                // We could add a strength/mix slider if desired in the future.
                Text("Normalization is automatic.")
                    .font(.caption)
                    .padding(.vertical, 5)
            }

            // Exposure & Contrast Section (using existing generic sliders)
            CollapsibleSection(isExpanded: $isExposureContrastExpanded, title: "Exposure & Contrast") {
                VStack {
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.exposure },
                        set: { viewModel.currentAdjustments.exposure = $0 }
                    ), title: "Exposure", range: -3.0...3.0, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.contrast },
                        set: { viewModel.currentAdjustments.contrast = $0 }
                    ), title: "Contrast", range: 0.0...4.0, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    // Slider for Lights
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.lights }, 
                        set: { viewModel.currentAdjustments.lights = $0 }
                    ), title: "Lights", range: 0.0...1.0, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    // Slider for Darks
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.darks }, 
                        set: { viewModel.currentAdjustments.darks = $0 }
                    ), title: "Darks", range: -1.0...1.0, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    // Slider for Whites
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.whites }, 
                        set: { viewModel.currentAdjustments.whites = $0 }
                    ), title: "Whites", range: min(1.0, viewModel.currentAdjustments.blacks + 0.01)...1.0, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    // Slider for Blacks
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.blacks }, 
                        set: { viewModel.currentAdjustments.blacks = $0 }
                    ), title: "Blacks", range: 0.0...max(0.0, viewModel.currentAdjustments.whites - 0.01), isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    // Add Brightness if it becomes part of this filter
                    Button("Reset Exposure & Contrast") {
                        viewModel.resetExposureContrast()
                    }
                    .padding(.top, 5)
                }
            }
            
            // Perceptual Tone Mapping Section
            CollapsibleSection(isExpanded: $isPerceptualToneMapExpanded, title: "Perceptual Tone Mapping (S-Curve)") {
                VStack {
                    AdjustmentSlider(value: Binding<Float>(
                        get: { Float(viewModel.currentAdjustments.sCurveShadowLift) }, 
                        set: { viewModel.currentAdjustments.sCurveShadowLift = CGFloat($0) }
                    ), title: "Shadow Lift", range: -0.25...0.25, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    AdjustmentSlider(value: Binding<Float>(
                        get: { Float(viewModel.currentAdjustments.sCurveHighlightPull) }, 
                        set: { viewModel.currentAdjustments.sCurveHighlightPull = CGFloat($0) }
                    ), title: "Highlight Pull", range: -0.25...0.25, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    // Gamma Slider
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.gamma },
                        set: { viewModel.currentAdjustments.gamma = $0 }
                    ), title: "Gamma", range: 0.2...3.0, isDisabled: false, onEditingChanged: {
                        viewModel.triggerImageProcessing()
                    })
                    Button("Reset Tone Mapping") {
                        viewModel.resetPerceptualToneMapping()
                    }
                    .padding(.top, 5)
                }
            }

            // NEW: Color Cast and Hue Refinement Section
            CollapsibleSection(isExpanded: $isColorCastRefinementExpanded, title: "Color Cast & Hue Refinements") {
                VStack { // Added VStack to hold controls and button
                    ColorCastRefinementControlsView(viewModel: viewModel)
                    Button("Reset Color Refinements") {
                        viewModel.resetColorCastAndHueRefinements()
                    }
                    .padding(.top, 5)
                }
            }

            // NEW: Geometry Section
            CollapsibleSection(isExpanded: $isGeometryExpanded, title: "Geometry") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: {
                            let currentAngle = viewModel.currentAdjustments.rotationAngle
                            viewModel.currentAdjustments.rotationAngle = (currentAngle + 90) % 360
                            viewModel.triggerImageProcessing()
                        }) {
                            Label("Rotate Left", systemImage: "rotate.left.fill")
                        }
                        Spacer()
                        Button(action: {
                            let currentAngle = viewModel.currentAdjustments.rotationAngle
                            viewModel.currentAdjustments.rotationAngle = ((currentAngle - 90) % 360 + 360) % 360
                            viewModel.triggerImageProcessing()
                        }) {
                            Label("Rotate Right", systemImage: "rotate.right.fill")
                        }
                    }
                    .padding(.vertical, 5)

                    Toggle(isOn: Binding(
                        get: { viewModel.currentAdjustments.isMirroredHorizontally },
                        set: { viewModel.currentAdjustments.isMirroredHorizontally = $0; viewModel.triggerImageProcessing() }
                    )) {
                        Text("Mirror horizontally")
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.currentAdjustments.isMirroredVertically },
                        set: { viewModel.currentAdjustments.isMirroredVertically = $0; viewModel.triggerImageProcessing() }
                    )) {
                        Text("Mirror vertically")
                    }
                    
                    Button("Reset Geometry") {
                        viewModel.resetGeometry()
                    }
                    .padding(.top, 5)
                }
                .padding(.vertical, 5)
            }

        }
    }
}

struct V2EditingControls_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = InversionViewModel()
        // Optionally set some default image or state for preview
        V2EditingControls(viewModel: viewModel)
            .padding()
            .frame(width: 280)
    }
} 
