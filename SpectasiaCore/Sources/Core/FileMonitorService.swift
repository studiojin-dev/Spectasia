import Foundation
import Dispatch

/// Service for monitoring file system changes in a directory
public class FileMonitorService {
    // MARK: - Types

    public typealias FileEventCallback = (URL) -> Void

    // MARK: - Properties

    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var monitoredDirectory: String?
    private var knownFiles: Set<String> = []
    private var knownModificationDates: [String: Date] = [:]
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.spectasia.fileMonitor", attributes: .concurrent)
    private let callbackQueue = DispatchQueue.main

    /// Callback invoked when a file is created
    public var onFileCreated: FileEventCallback?

    /// Callback invoked when a file is deleted
    public var onFileDeleted: FileEventCallback?

    /// Callback invoked when a file is modified
    public var onFileModified: FileEventCallback?

    // MARK: - Supported Image Extensions

    private let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "bmp", "webp"
    ]

    // MARK: - Initialization

    public init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring a directory for file changes
    /// - Parameter directory: Path to the directory to monitor
    public func startMonitoring(directory: String) throws {
        // Stop existing monitoring if any
        stopMonitoring()

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw MonitorError.directoryNotFound
        }

        monitoredDirectory = directory

        // Initialize known files
        if let contents = try? fileManager.contentsOfDirectory(atPath: directory) {
            let imageFiles = contents.filter { filename in
                let path = (directory as NSString).appendingPathComponent(filename)
                return isImageFile(URL(fileURLWithPath: path))
            }
            knownFiles = Set(imageFiles)
            knownModificationDates = loadModificationDates(directory: directory, filenames: imageFiles)
        }

        // Create file descriptor for the directory
        fileDescriptor = open(directory, O_EVTONLY)
        guard fileDescriptor != -1 else {
            throw MonitorError.cannotOpenDirectory
        }

        // Create dispatch source for file system events
        fileSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .all,
            queue: queue
        )

        // Set event handler
        fileSource?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }

        // Start monitoring
        fileSource?.resume()
    }

    /// Stop monitoring the current directory
    public func stopMonitoring() {
        fileSource?.cancel()
        fileSource = nil

        // Close file descriptor to prevent resource leak
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        monitoredDirectory = nil
        knownFiles.removeAll()
        knownModificationDates.removeAll()
    }

    // MARK: - Private Methods

    private func handleFileSystemEvent() {
        guard let directory = monitoredDirectory else { return }

        // Get current state of directory
        guard let contents = try? fileManager.contentsOfDirectory(
            atPath: directory
        ) else { return }

        let currentImageFiles = Set(contents.filter { filename in
            let path = (directory as NSString).appendingPathComponent(filename)
            return isImageFile(URL(fileURLWithPath: path))
        })
        let currentModificationDates = loadModificationDates(directory: directory, filenames: Array(currentImageFiles))

        // Detect new files
        let newFiles = currentImageFiles.subtracting(knownFiles)
        for filename in newFiles {
            let path = (directory as NSString).appendingPathComponent(filename)
            let fileURL = URL(fileURLWithPath: path)
            callbackQueue.async { [weak self] in
                self?.onFileCreated?(fileURL)
            }
        }

        // Detect deleted files
        let deletedFiles = knownFiles.subtracting(currentImageFiles)
        for filename in deletedFiles {
            let path = (directory as NSString).appendingPathComponent(filename)
            let fileURL = URL(fileURLWithPath: path)
            callbackQueue.async { [weak self] in
                self?.onFileDeleted?(fileURL)
            }
        }

        // Detect modified files
        let commonFiles = knownFiles.intersection(currentImageFiles)
        for filename in commonFiles {
            let previousDate = knownModificationDates[filename]
            let currentDate = currentModificationDates[filename]
            if let previousDate, let currentDate, currentDate > previousDate {
                let path = (directory as NSString).appendingPathComponent(filename)
                let fileURL = URL(fileURLWithPath: path)
                callbackQueue.async { [weak self] in
                    self?.onFileModified?(fileURL)
                }
            }
        }

        // Update known files
        knownFiles = currentImageFiles
        knownModificationDates = currentModificationDates
    }

    private func isImageFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }

    private func loadModificationDates(directory: String, filenames: [String]) -> [String: Date] {
        var results: [String: Date] = [:]
        for filename in filenames {
            let path = (directory as NSString).appendingPathComponent(filename)
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let modified = attrs[.modificationDate] as? Date {
                results[filename] = modified
            }
        }
        return results
    }
}

// MARK: - Errors

public enum MonitorError: Error {
    case directoryNotFound
    case cannotOpenDirectory
}
