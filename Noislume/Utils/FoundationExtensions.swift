import Foundation

extension NumberFormatter {
    static var percentageFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal // Use .decimal and handle % symbol in UI if direct percentage input (e.g., "10") is desired.
                                        // Or use .percent and ensure input is treated as 0.10 for 10%.
                                        // For a TextField taking a Double that represents a whole number percentage (e.g., 10.0 for 10%),
                                        // .decimal is often simpler and you append "%" in the UI.
                                        // If you want the formatter to automatically handle "10%" as 0.1, then .percent is better.
                                        // Given the Stepper and direct value binding, .decimal with manual "%" in UI is common.
                                        // Let's assume we want to display whole numbers for percentages.
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1 // Allow for one decimal place if needed, e.g., 10.5%
        formatter.multiplier = 1 // If the input value is already scaled (e.g., 10 for 10%)
        // If you were using .percent style and wanted "10" to mean 10%, you'd set multiplier to 1.
        // If your model stores 0.1 for 10%, and you use .percent, multiplier would be 100.
        // Given cropInsetPercentage is likely stored as 10.0 for 10%, .decimal is fine.
        return formatter
    }
} 