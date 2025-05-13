import Foundation
import os.log
import CryptoKit // Import for SHA256

/// Manages the persistence of application data, such as individual image editing states.
class PersistenceManager {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "PersistenceManager")
    private let fileManager = FileManager.default
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    /// The filename used for storing image states.
    private let imageStatesFilename = "imageStates.json"

    /// Returns the URL for the directory used to store application support files.
    /// Creates the directory if it doesn't exist.
    private var applicationSupportDirectory: URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Could not find application support directory.")
            return nil
        }
        
        // Append your app's bundle identifier (or a unique name) to create a dedicated folder
        let bundleID = Bundle.main.bundleIdentifier ?? "com.SpencerCurtis.Noislume"
        let appDirectoryURL = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        let statesDirectoryURL = appDirectoryURL.appendingPathComponent("ImageStates", isDirectory: true) // Subdirectory for states

        // Create the directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: statesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            return statesDirectoryURL // Return the ImageStates subdirectory
        } catch {
            logger.error("Could not create ImageStates directory at \(statesDirectoryURL.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns the full file URL for storing the image states.
    private var imageStatesFileURL: URL? {
        applicationSupportDirectory?.appendingPathComponent(imageStatesFilename)
    }

    /// Generates a safe filename from a URL string using SHA256 hash.
    /// - Parameter urlString: The absolute string of the image URL.
    /// - Returns: A filename ending in .json, or nil if hashing fails.
    private func stateFilename(for urlString: String) -> String? {
        guard let data = urlString.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined() + ".json"
    }
    
    /// Returns the full file URL for storing a specific image state.
    /// - Parameter url: The URL of the image.
    /// - Returns: The file URL, or nil if the directory or filename cannot be determined.
    private func stateFileURL(for url: URL) -> URL? {
        guard let dir = applicationSupportDirectory, 
              let filename = stateFilename(for: url.absoluteString) else { 
            logger.error("Could not generate file URL for state of \(url.absoluteString)")
            return nil 
        }
        return dir.appendingPathComponent(filename)
    }

    /// Saves the given image states dictionary to a file.
    /// - Parameter states: A dictionary mapping image URLs (as Strings) to their ImageState.
    func saveImageStates(_ states: [String: ImageState]) {
        guard let fileURL = imageStatesFileURL else {
            logger.error("Cannot save image states: file URL is invalid.")
            return
        }

        do {
            let data = try jsonEncoder.encode(states)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Successfully saved \(states.count) image states to \(fileURL.path)")
        } catch {
            logger.error("Failed to save image states to \(fileURL.path): \(error.localizedDescription)")
        }
    }

    /// Loads the image states dictionary from a file.
    /// - Returns: A dictionary mapping image URLs (as Strings) to their ImageState, or an empty dictionary if loading fails.
    func loadImageStates() -> [String: ImageState] {
        guard let fileURL = imageStatesFileURL else {
            logger.error("Cannot load image states: file URL is invalid.")
            return [:]
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
             logger.info("Image states file does not exist at \(fileURL.path). Returning empty state.")
            return [:]
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let states = try jsonDecoder.decode([String: ImageState].self, from: data)
            logger.info("Successfully loaded \(states.count) image states from \(fileURL.path)")
            return states
        } catch {
            logger.error("Failed to load or decode image states from \(fileURL.path): \(error.localizedDescription)")
            return [:]
        }
    }

    /// Saves a single ImageState to its dedicated file.
    /// - Parameter state: The ImageState object to save.
    func saveImageState(_ state: ImageState) {
        guard let url = state.imageURL, // Get the URL from the state itself
              let fileURL = stateFileURL(for: url) else {
            logger.error("Cannot save image state: invalid URL in state or could not generate file path.")
            return
        }

        do {
            let data = try jsonEncoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
            logger.debug("Successfully saved image state to \(fileURL.path)") // Use debug level
        } catch {
            logger.error("Failed to save image state to \(fileURL.path): \(error.localizedDescription)")
        }
    }

    /// Loads a single ImageState from its dedicated file.
    /// - Parameter url: The URL of the image whose state should be loaded.
    /// - Returns: The loaded ImageState, or nil if the file doesn't exist or loading/decoding fails.
    func loadImageState(for url: URL) -> ImageState? {
        guard let fileURL = stateFileURL(for: url) else {
            logger.error("Cannot load image state for \(url.absoluteString): file URL is invalid.")
            return nil
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
             logger.debug("Image state file does not exist for \(url.absoluteString). No state to load.") // Use debug
            return nil // No state saved yet for this URL
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let state = try jsonDecoder.decode(ImageState.self, from: data)
            // Optional: Verify the loaded state's URL matches the requested URL
            guard state.imageURLString == url.absoluteString else {
                logger.warning("Loaded state file at \(fileURL.path) contains mismatched URL: \(state.imageURLString). Ignoring.")
                return nil
            }
            logger.debug("Successfully loaded image state for \(url.absoluteString) from \(fileURL.path)") // Use debug
            return state
        } catch {
            logger.error("Failed to load or decode image state for \(url.absoluteString) from \(fileURL.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Optional: Add a function to clean up potentially orphaned state files if needed later.
    // func cleanupOrphanedStates(validURLs: Set<URL>) { ... }
} 