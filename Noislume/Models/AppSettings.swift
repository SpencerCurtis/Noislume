import Foundation

class AppSettings: ObservableObject {
    @Published var cropInsetPercentage: Double {
        didSet {
            UserDefaults.standard.set(cropInsetPercentage, forKey: "cropInsetPercentage")
        }
    }
    
    @Published var showOriginalWhenCropping: Bool {
        didSet {
            UserDefaults.standard.set(showOriginalWhenCropping, forKey: "showOriginalWhenCropping")
        }
    }
    
    init() {
        // Default to 5% if no value is saved
        self.cropInsetPercentage = UserDefaults.standard.double(forKey: "cropInsetPercentage").nonZeroValue ?? 5.0
        // Default to false if no value is saved
        self.showOriginalWhenCropping = UserDefaults.standard.bool(forKey: "showOriginalWhenCropping")
    }
}

private extension Double {
    var nonZeroValue: Double? {
        return self != 0 ? self : nil
    }
}
