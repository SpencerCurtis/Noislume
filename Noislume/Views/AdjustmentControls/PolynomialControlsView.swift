import SwiftUI

struct PolynomialControlsView: View {
    @ObservedObject var viewModel: InversionViewModel

    // Define a common number formatter for the TextFields
    private var formatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Polynomial Curve Coefficients")
                .font(.headline)
            
            // Red Channel
            Group {
                Text("Red Channel").font(.subheadline)
                HStack {
                    Text("Linear (Y):")
                    Slider(value: $viewModel.polyRedLinear, in: 0.0...2.0, step: 0.01) { editing in
                        if !editing { viewModel.triggerImageProcessing() }
                    }
                    TextField("", value: $viewModel.polyRedLinear, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
                HStack {
                    Text("Quadratic (Z):")
                    Slider(value: $viewModel.polyRedQuadratic, in: -1.0...1.0, step: 0.01) { editing in
                        if !editing { viewModel.triggerImageProcessing() }
                    }
                    TextField("", value: $viewModel.polyRedQuadratic, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            // Green Channel
            Group {
                Text("Green Channel").font(.subheadline)
                HStack {
                    Text("Linear (Y):")
                    Slider(value: $viewModel.polyGreenLinear, in: 0.0...2.0, step: 0.01) { editing in
                        if !editing { viewModel.triggerImageProcessing() }
                    }
                    TextField("", value: $viewModel.polyGreenLinear, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
                HStack {
                    Text("Quadratic (Z):")
                    Slider(value: $viewModel.polyGreenQuadratic, in: -1.0...1.0, step: 0.01) { editing in
                        if !editing { viewModel.triggerImageProcessing() }
                    }
                    TextField("", value: $viewModel.polyGreenQuadratic, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
            }
            
            Divider().padding(.vertical, 4)

            // Blue Channel
            Group {
                Text("Blue Channel").font(.subheadline)
                HStack {
                    Text("Linear (Y):")
                    Slider(value: $viewModel.polyBlueLinear, in: 0.0...2.0, step: 0.01) { editing in
                        if !editing { viewModel.triggerImageProcessing() }
                    }
                    TextField("", value: $viewModel.polyBlueLinear, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
                HStack {
                    Text("Quadratic (Z):")
                    Slider(value: $viewModel.polyBlueQuadratic, in: -1.0...1.0, step: 0.01) { editing in
                        if !editing { viewModel.triggerImageProcessing() }
                    }
                    TextField("", value: $viewModel.polyBlueQuadratic, formatter: formatter)
                        .textFieldStyle( RoundedBorderTextFieldStyle()).frame(width: 60)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct PolynomialControlsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy ViewModel for preview
        let dummyViewModel = InversionViewModel()
        // You might want to set some initial values on dummyViewModel.currentAdjustments
        // for more representative preview if needed.
        
        PolynomialControlsView(viewModel: dummyViewModel)
            .padding()
            .frame(width: 300)
    }
} 