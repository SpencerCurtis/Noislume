import SwiftUI

struct V2EditingControls: View {
    @ObservedObject var viewModel: InversionViewModel
    // Add any @State variables needed for V2 controls here

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Processing V2 Controls")
                .font(.headline)
                .padding(.bottom, 5)
            
            // New Toggle for post-geometry filter processing
            Toggle("Apply Full Processing (Post-Geometry)", isOn: Binding(
                get: { viewModel.currentAdjustments.applyPostGeometryFilters },
                set: { 
                    viewModel.currentAdjustments.applyPostGeometryFilters = $0
                    // The view model should automatically handle reprocessing due to currentAdjustments being @Published
                }
            ))
            .padding(.bottom, 10)
            
            // Film Base Neutralization Section (existing)
            CollapsibleSection(sectionKey: "v2FilmBase", title: "Film Base Neutralization", defaultExpanded: true, resetAction: viewModel.clearFilmBaseSample) {
                VStack {
                    Button(action: {
                        viewModel.isSamplingFilmBaseColor.toggle()
                    }) {
                        Label(viewModel.isSamplingFilmBaseColor ? "Sampling... (Tap Image)" : "Sample Film Base Color", systemImage: "eyedropper")
                    }
                    #if os(macOS)
                    .help("Sample a point on the image that should be neutral (e.g., unexposed film base between frames). This color will be used to neutralize the film base tint.")
                    #endif
                    
                    if let sampledColor = viewModel.currentAdjustments.filmBaseSamplePointColor {
                        HStack {
                            Text("Selected Base Color:")
                            Rectangle()
                                .fill(Color(red: sampledColor.red, green: sampledColor.green, blue: sampledColor.blue, opacity: sampledColor.alpha))
                                .frame(width: 20, height: 20)
                                .border(Color.gray)
                        }.padding(.top, 5)
                    }
                }
                .padding(.vertical, 5)
            }
            
//            // Auto Levels Channel Normalization (existing controls, if any - placeholder)
//            CollapsibleSection(sectionKey: "v2AutoLevels", title: "Auto Levels Normalization", defaultExpanded: false) {
//                // Currently, this filter is fully automatic based on histogram.
//                // We could add a strength/mix slider if desired in the future.
//                Text("Normalization is automatic.")
//                    .font(.caption)
//                    .padding(.vertical, 5)
//            }

            // Exposure & Contrast Section (using existing generic sliders)
            CollapsibleSection(sectionKey: "v2ExposureContrast", title: "Exposure & Contrast", defaultExpanded: true, resetAction: viewModel.resetExposureContrast) {
                VStack {
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.exposure },
                        set: { viewModel.currentAdjustments.exposure = $0 }
                    ), title: "Exposure", range: -3.0...3.0, isDisabled: false)
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.contrast },
                        set: { viewModel.currentAdjustments.contrast = $0 }
                    ), title: "Contrast", range: 0.0...4.0, isDisabled: false)
                    // Slider for Lights
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.lights }, 
                        set: { viewModel.currentAdjustments.lights = $0 }
                    ), title: "Lights", range: 0.0...1.0, isDisabled: false)
                    // Slider for Darks
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.darks }, 
                        set: { viewModel.currentAdjustments.darks = $0 }
                    ), title: "Darks", range: -1.0...1.0, isDisabled: false)
                    // Slider for Whites
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.whites }, 
                        set: { viewModel.currentAdjustments.whites = $0 }
                    ), title: "Whites", range: min(1.0, viewModel.currentAdjustments.blacks + 0.01)...1.0, isDisabled: false)
                    // Slider for Blacks
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.blacks }, 
                        set: { viewModel.currentAdjustments.blacks = $0 }
                    ), title: "Blacks", range: 0.0...max(0.0, viewModel.currentAdjustments.whites - 0.01), isDisabled: false)
                }
            }
            
            // Perceptual Tone Mapping Section
            CollapsibleSection(sectionKey: "v2ToneMapping", title: "Perceptual Tone Mapping (S-Curve)", defaultExpanded: true, resetAction: viewModel.resetPerceptualToneMapping) {
                VStack {
                    AdjustmentSlider(value: Binding<Float>(
                        get: { Float(viewModel.currentAdjustments.sCurveShadowLift) }, 
                        set: { viewModel.currentAdjustments.sCurveShadowLift = CGFloat($0) }
                    ), title: "Shadow Lift", range: -0.25...0.25, isDisabled: false)
                    AdjustmentSlider(value: Binding<Float>(
                        get: { Float(viewModel.currentAdjustments.sCurveHighlightPull) }, 
                        set: { viewModel.currentAdjustments.sCurveHighlightPull = CGFloat($0) }
                    ), title: "Highlight Pull", range: -0.25...0.25, isDisabled: false)
                    // Gamma Slider
                    AdjustmentSlider(value: Binding<Float>(
                        get: { viewModel.currentAdjustments.gamma },
                        set: { viewModel.currentAdjustments.gamma = $0 }
                    ), title: "Gamma", range: 0.2...3.0, isDisabled: false)
                }
                .padding(.vertical, 5)
            }

            // NEW: Color Cast and Hue Refinement Section
            CollapsibleSection(sectionKey: "v2ColorCastHue", title: "Color Cast & Hue Refinements", defaultExpanded: true, resetAction: viewModel.resetColorCastAndHueRefinements) {
                VStack {
                    // Midtone Neutralization Toggle
                    Toggle("Apply Midtone Neutralization", isOn: viewModel.applyMidtoneNeutralizationBinding)
                        .padding(.horizontal)
                    
                    // Other controls for this section would go here...
                    // e.g., Sliders for midtoneNeutralizationStrength, shadow/highlight tint angles, strengths, color pickers
                    
                }
            }

            // NEW: Sharpening & Noise Reduction Section
            CollapsibleSection(sectionKey: "v2SharpenNoise", title: "Sharpening & Noise Reduction", defaultExpanded: true, resetAction: { viewModel.resetSharpeningAndNoiseReduction() } ) {
                VStack {
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.sharpness },
                        set: { viewModel.currentAdjustments.sharpness = $0 }
                    ), title: "Sharpness (Luminance)", range: 0.0...1.0, isDisabled: false)
                    
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.unsharpMaskRadius },
                        set: { viewModel.currentAdjustments.unsharpMaskRadius = $0 }
                    ), title: "Unsharp Mask Radius", range: 0.0...10.0, isDisabled: false)

                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.unsharpMaskIntensity },
                        set: { viewModel.currentAdjustments.unsharpMaskIntensity = $0 }
                    ), title: "Unsharp Mask Intensity", range: 0.0...2.0, isDisabled: false)
                    
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.luminanceNoise },
                        set: { viewModel.currentAdjustments.luminanceNoise = $0 }
                    ), title: "Luminance Noise Reduction", range: 0.0...1.0, isDisabled: false)
                    
                    AdjustmentSlider(value: Binding(
                        get: { viewModel.currentAdjustments.noiseReduction },
                        set: { viewModel.currentAdjustments.noiseReduction = $0 }
                    ), title: "NR Detail / Sharpness", range: 0.0...5.0, isDisabled: false)
                }
                .padding(.vertical, 5)
            }

            // NEW: Black and White Section
            CollapsibleSection(sectionKey: "v2BlackAndWhite", title: "Black and White", defaultExpanded: false, resetAction: {
                withAnimation {
                    viewModel.currentAdjustments.bwRedContribution = 1.0
                    viewModel.currentAdjustments.bwGreenContribution = 1.0
                    viewModel.currentAdjustments.bwBlueContribution = 1.0
                    viewModel.currentAdjustments.sepiaIntensity = 0.0
                }
            }) {
                VStack(spacing: 12) {
                    Toggle("Convert to Black and White", isOn: $viewModel.currentAdjustments.isBlackAndWhite)
                        .toggleStyle(.switch)
                        .padding(.bottom, 4)
                    
                    if viewModel.currentAdjustments.isBlackAndWhite {
                        AdjustmentSlider(
                            value: $viewModel.currentAdjustments.bwRedContribution,
                            title: "Red",
                            range: -1.0...2.0,
                            isDisabled: !viewModel.currentAdjustments.isBlackAndWhite
                        )
                        
                        AdjustmentSlider(
                            value: $viewModel.currentAdjustments.bwGreenContribution,
                            title: "Green",
                            range: -1.0...2.0,
                            isDisabled: !viewModel.currentAdjustments.isBlackAndWhite
                        )
                        
                        AdjustmentSlider(
                            value: $viewModel.currentAdjustments.bwBlueContribution,
                            title: "Blue",
                            range: -1.0...2.0,
                            isDisabled: !viewModel.currentAdjustments.isBlackAndWhite
                        )
                        
                        AdjustmentSlider(
                            value: $viewModel.currentAdjustments.sepiaIntensity,
                            title: "Sepia Tone",
                            range: 0.0...1.0,
                            isDisabled: !viewModel.currentAdjustments.isBlackAndWhite
                        )
                    }
                }
            }

            // NEW: Geometry Section
            CollapsibleSection(sectionKey: "v2Geometry", title: "Geometry", defaultExpanded: false, resetAction: viewModel.resetGeometry) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: {
                            let currentAngle = viewModel.currentAdjustments.rotationAngle
                            viewModel.currentAdjustments.rotationAngle = (currentAngle + 90) % 360
                        }) {
                            Label("Rotate Left", systemImage: "rotate.left.fill")
                        }
                        Spacer()
                        Button(action: {
                            let currentAngle = viewModel.currentAdjustments.rotationAngle
                            viewModel.currentAdjustments.rotationAngle = ((currentAngle - 90) % 360 + 360) % 360
                        }) {
                            Label("Rotate Right", systemImage: "rotate.right.fill")
                        }
                    }
                    .padding(.vertical, 5)

                    Toggle(isOn: Binding(
                        get: { viewModel.currentAdjustments.isMirroredHorizontally },
                        set: { 
                            viewModel.currentAdjustments.isMirroredHorizontally = $0
                        }
                    )) {
                        Text("Mirror vertically")
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.currentAdjustments.isMirroredVertically }, 
                        set: { 
                            viewModel.currentAdjustments.isMirroredVertically = $0
                        }
                    )) {
                        Text("Mirror horizontally")
                    }
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
