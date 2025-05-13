import Foundation

/// Manages navigation through a list of image file URLs.
struct ImageFileNavigator {
    private(set) var fileURLs: [URL] = []
    private(set) var activeIndex: Int? = nil

    var currentURL: URL? {
        guard let index = activeIndex, index >= 0, index < fileURLs.count else {
            return nil
        }
        return fileURLs[index]
    }
    
    var count: Int {
        fileURLs.count
    }
    
    var isEmpty: Bool {
        fileURLs.isEmpty
    }

    /// Sets the list of file URLs and optionally sets the active index.
    /// - Parameters:
    ///   - urls: The array of URLs to manage.
    ///   - initialIndex: The index to set as active initially. Defaults to 0 if urls is not empty, otherwise nil.
    mutating func setFiles(_ urls: [URL], initialIndex: Int? = nil) {
        self.fileURLs = urls
        if urls.isEmpty {
            self.activeIndex = nil
        } else {
            let defaultIndex = urls.isEmpty ? nil : 0
            let targetIndex = initialIndex ?? defaultIndex
            // Validate the target index
            if let idx = targetIndex, idx >= 0 && idx < urls.count {
                self.activeIndex = idx
            } else {
                self.activeIndex = defaultIndex // Fallback to 0 or nil
            }
        }
    }

    /// Sets the active index. Returns true if the index was valid and set, false otherwise.
    /// - Parameter index: The index to make active.
    /// - Returns: Bool indicating success.
    @discardableResult
    mutating func setActiveIndex(_ index: Int) -> Bool {
        guard index >= 0 && index < fileURLs.count else {
            return false
        }
        self.activeIndex = index
        return true
    }
    
    /// Resets the navigator to an empty state.
    mutating func reset() {
        self.fileURLs = []
        self.activeIndex = nil
    }
} 