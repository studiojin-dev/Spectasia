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
            knownFiles = Set(contents.filter { filename in
                let path = (directory as NSString).appendingPathComponent(filename)
                return isImageFile(URL(fileURLWithPath: path))
            })
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

        // Update known files
        knownFiles = currentImageFiles
    }

    private func isImageFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
}

// MARK: - Errors

public enum MonitorError: Error {
    case directoryNotFound
    case cannotOpenDirectory
}
