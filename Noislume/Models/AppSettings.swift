
import Foundation

class AppSettings: ObservableObject {
    @Published var cropInsetPercentage: Double {
        didSet {
            UserDefaults.standard.set(cropInsetPercentage, forKey: "cropInsetPercentage")
        }
    }
    
    init() {
        // Default to 5% if no value is saved
        self.cropInsetPercentage = UserDefaults.standard.double(forKey: "cropInsetPercentage").nonZeroValue ?? 5.0
    }
}

private extension Double {
    var nonZeroValue: Double? {
        return self != 0 ? self : nil
    }
}
