import Foundation

enum ProcessingVersion: String, CaseIterable, Identifiable {
    case v1 = "Version 1"
    case v2 = "Version 2"

    var id: String { self.rawValue }
} 