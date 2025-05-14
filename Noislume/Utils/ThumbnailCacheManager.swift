import Foundation
import AppKit // For NSImage
import os.log
import CryptoKit

/// Manages storing and retrieving generated thumbnail images from a file cache.
class ThumbnailCacheManager {
    private let logger = Logger(subsystem: "com.SpencerCurtis.Noislume", category: "ThumbnailCacheManager")
    private let fileManager = FileManager.default
    private let appSettings: AppSettings // To access cache size limit

    /// The subdirectory name within Application Support for thumbnail files.
    private let cacheDirectoryName = "Thumbnails"

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        // Initial check of cache size on startup
        DispatchQueue.global(qos: .background).async {
            self.enforceSizeLimit()
        }
    }

    /// Returns the URL for the directory used to store thumbnail files.
    /// Creates the directory if it doesn't exist.
    private var cacheDirectory: URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Could not find application support directory.")
            return nil
        }
        
        let bundleID = Bundle.main.bundleIdentifier ?? "com.SpencerCurtis.Noislume"
        let appDirectoryURL = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        let thumbnailsDirectoryURL = appDirectoryURL.appendingPathComponent(cacheDirectoryName, isDirectory: true)

        // Create the directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: thumbnailsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            return thumbnailsDirectoryURL
        } catch {
            logger.error("Could not create thumbnail cache directory at \(thumbnailsDirectoryURL.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Generates a safe filename from an original image URL string using SHA256 hash.
    /// - Parameter urlString: The absolute string of the original image URL.
    /// - Returns: A filename ending in .png, or nil if hashing fails.
    private func cacheFilename(for urlString: String) -> String? {
        guard let data = urlString.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: data)
        // Using PNG format for cached thumbnails
        return hash.compactMap { String(format: "%02x", $0) }.joined() + ".png" 
    }

    /// Returns the full file URL for storing a specific thumbnail.
    /// - Parameter imageURL: The URL of the original image.
    /// - Returns: The file URL for the cached thumbnail, or nil if the directory or filename cannot be determined.
    func cacheFileURL(for imageURL: URL) -> URL? {
        guard let dir = cacheDirectory,
              let filename = cacheFilename(for: imageURL.absoluteString) else {
            logger.error("Could not generate file URL for thumbnail cache of \(imageURL.absoluteString)")
            return nil
        }
        return dir.appendingPathComponent(filename)
    }

    /// Saves a thumbnail NSImage as PNG data to its cache file.
    /// - Parameters:
    ///   - image: The NSImage thumbnail to save.
    ///   - imageURL: The URL of the original image this thumbnail represents.
    func saveThumbnail(_ image: NSImage, for imageURL: URL) {
        guard let fileURL = cacheFileURL(for: imageURL) else {
            logger.error("Cannot save thumbnail: could not get file URL for \(imageURL.absoluteString)")
            return
        }

        // Convert NSImage to PNG Data
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            logger.error("Failed to get CGImage for thumbnail of \(imageURL.absoluteString)")
            return
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            logger.error("Failed to get PNG data representation for thumbnail of \(imageURL.absoluteString)")
            return
        }

        do {
            try pngData.write(to: fileURL, options: .atomic)
            logger.debug("Successfully saved thumbnail to file cache: \(fileURL.path)")
            // After saving, enforce the size limit asynchronously
            DispatchQueue.global(qos: .background).async {
                self.enforceSizeLimit()
            }
        } catch {
            logger.error("Failed to write thumbnail file cache to \(fileURL.path): \(error.localizedDescription)")
        }
    }

    /// Loads thumbnail data from its cache file.
    /// - Parameter imageURL: The URL of the original image.
    /// - Returns: The raw Data of the cached PNG thumbnail, or nil if not found or error occurred.
    func loadThumbnailData(for imageURL: URL) -> Data? {
        guard let fileURL = cacheFileURL(for: imageURL) else {
            logger.error("Cannot load thumbnail data: could not get file URL for \(imageURL.absoluteString)")
            return nil
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.trace("Thumbnail file cache does not exist for \(imageURL.absoluteString)")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            logger.debug("Successfully loaded thumbnail data from file cache: \(fileURL.path)")
            return data
        } catch {
            logger.error("Failed to load thumbnail data from file cache \(fileURL.path): \(error.localizedDescription)")
            // Optionally remove corrupted file?
            // try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    /// Removes a specific thumbnail file from the cache.
    /// - Parameter imageURL: The URL of the original image whose thumbnail should be removed.
    func removeThumbnail(for imageURL: URL) {
        guard let fileURL = cacheFileURL(for: imageURL) else {
            logger.error("Cannot remove thumbnail: could not get file URL for \(imageURL.absoluteString)")
            return
        }

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
                logger.debug("Removed thumbnail file cache for \(imageURL.absoluteString) at \(fileURL.path)")
            } catch {
                logger.error("Failed to remove thumbnail file cache at \(fileURL.path): \(error.localizedDescription)")
            }
        }
    }

    /// Removes all files from the thumbnail cache directory.
    func clearCache() {
        guard let dirURL = cacheDirectory else {
            logger.error("Cannot clear thumbnail cache: directory URL is invalid.")
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [])
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
            logger.info("Cleared all items from thumbnail file cache directory: \(dirURL.path)")
        } catch {
             logger.error("Failed to clear thumbnail file cache directory at \(dirURL.path): \(error.localizedDescription)")
        }
    }

    private func enforceSizeLimit() {
        guard appSettings.enableThumbnailFileCache, let dirURL = cacheDirectory else {
            // Cache is disabled or directory is unavailable
            return
        }
        
        // Log the directory being checked
//        logger.debug("Enforcing size limit: Checking directory at \(dirURL.path)")

        let maxSizeInBytes = Int64(appSettings.thumbnailCacheSizeLimitMB) * 1024 * 1024
        var currentSize: Int64 = 0
        var filesWithDateAndSize: [(url: URL, date: Date, size: Int64)] = []

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.contentModificationDateKey, .totalFileSizeKey, .isDirectoryKey], options: .skipsHiddenFiles)

            // Log how many items were found initially
            logger.debug("Found \(fileURLs.count) items in cache directory initially.")

            for fileURL in fileURLs {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .totalFileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == true {
                    // Log skipped directories
                    logger.trace("Skipping directory: \(fileURL.lastPathComponent)")
                    continue // Skip directories
                }
                guard let modificationDate = resourceValues.contentModificationDate, let fileSize = resourceValues.totalFileSize else {
                    logger.warning("Could not get attributes for file: \(fileURL.path)")
                    continue
                }
                // Log the file being processed and its size
                currentSize += Int64(fileSize)
                filesWithDateAndSize.append((url: fileURL, date: modificationDate, size: Int64(fileSize)))
            }

            // Log the calculated total size before comparison
            logger.debug("Calculated total cache size: \(currentSize) bytes (\(currentSize / 1024 / 1024)MB)")

            if currentSize > maxSizeInBytes {
                logger.info("Thumbnail cache size (\(currentSize / 1024 / 1024)MB) exceeds limit (\(self.appSettings.thumbnailCacheSizeLimitMB)MB). Pruning...")
                // Sort files by modification date, oldest first
                filesWithDateAndSize.sort { $0.date < $1.date }

                var removedCount = 0
                while currentSize > maxSizeInBytes && !filesWithDateAndSize.isEmpty {
                    let oldestFile = filesWithDateAndSize.removeFirst()
                    do {
                        try fileManager.removeItem(at: oldestFile.url)
                        currentSize -= oldestFile.size
                        removedCount += 1
                        logger.debug("Removed old thumbnail: \(oldestFile.url.lastPathComponent), new size: \(currentSize / 1024 / 1024)MB")
                    } catch {
                        logger.error("Failed to remove old thumbnail \(oldestFile.url.path): \(error.localizedDescription)")
                        // Stop trying if one fails, or it might loop excessively on permission issues
                        break 
                    }
                }
                logger.info("Pruned \(removedCount) old thumbnails. Current cache size: \(currentSize / 1024 / 1024)MB")
            } else {
                logger.debug("Thumbnail cache size (\(currentSize / 1024 / 1024)MB) is within limit (\(self.appSettings.thumbnailCacheSizeLimitMB)MB). No pruning needed.")
            }

        } catch {
//            logger.error("Error enforcing thumbnail cache size limit: \(error.localizedDescription)")
        }
    }
} 
