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
            VStack(alignment: .leading) {
                Text("Red Channel").font(.subheadline)
                HStack {
                    Text("Linear (Y):")
                    Slider(value: $viewModel.currentAdjustments.polyRedLinear, in: 0.0...2.0, step: 0.01)
                    TextField("", value: $viewModel.currentAdjustments.polyRedLinear, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
                HStack {
                    Text("Quadratic (Z):")
                    Slider(value: $viewModel.currentAdjustments.polyRedQuadratic, in: -1.0...1.0, step: 0.01)
                    TextField("", value: $viewModel.currentAdjustments.polyRedQuadratic, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            // Green Channel
            VStack(alignment: .leading) {
                Text("Green Channel").font(.subheadline)
                HStack {
                    Text("Linear (Y):")
                    Slider(value: $viewModel.currentAdjustments.polyGreenLinear, in: 0.0...2.0, step: 0.01)
                    TextField("", value: $viewModel.currentAdjustments.polyGreenLinear, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
                HStack {
                    Text("Quadratic (Z):")
                    Slider(value: $viewModel.currentAdjustments.polyGreenQuadratic, in: -1.0...1.0, step: 0.01)
                    TextField("", value: $viewModel.currentAdjustments.polyGreenQuadratic, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
            }
            
            Divider().padding(.vertical, 4)

            // Blue Channel
            VStack(alignment: .leading) {
                Text("Blue Channel").font(.subheadline)
                HStack {
                    Text("Linear (Y):")
                    Slider(value: $viewModel.currentAdjustments.polyBlueLinear, in: 0.0...2.0, step: 0.01)
                    TextField("", value: $viewModel.currentAdjustments.polyBlueLinear, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60)
                }
                HStack {
                    Text("Quadratic (Z):")
                    Slider(value: $viewModel.currentAdjustments.polyBlueQuadratic, in: -1.0...1.0, step: 0.01)
                    TextField("", value: $viewModel.currentAdjustments.polyBlueQuadratic, formatter: formatter)
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