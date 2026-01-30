import Foundation
import Dispatch
import CoreServices

/// Service for monitoring file system changes in a directory
public class FileMonitorService {
    // MARK: - Types

    public typealias FileEventCallback = (URL) -> Void

    // MARK: - Properties

    private var stream: FSEventStreamRef?
    private var monitoredDirectory: String?
    private var knownFiles: Set<String> = []
    private var knownModificationDates: [String: Date] = [:]
    private var knownSizes: [String: Int64] = [:]
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
            knownSizes = loadSizes(directory: directory, filenames: imageFiles)
        }

        let pathsToWatch = [directory] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, info, numEvents, eventPaths, eventFlags, _) in
                guard let info else { return }
                let monitor = Unmanaged<FileMonitorService>.fromOpaque(info).takeUnretainedValue()
                let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
                for index in 0..<numEvents {
                    let path = paths[Int(index)]
                    let flags = eventFlags[Int(index)]
                    monitor.handleEvent(path: path, flags: flags)
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        )

        guard let stream else {
            throw MonitorError.cannotOpenDirectory
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    /// Stop monitoring the current directory
    public func stopMonitoring() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }

        monitoredDirectory = nil
        knownFiles.removeAll()
        knownModificationDates.removeAll()
        knownSizes.removeAll()
    }

    // MARK: - Private Methods

    private func handleEvent(path: String, flags: FSEventStreamEventFlags) {
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0 ||
            flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped) != 0 ||
            flags & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped) != 0 {
            performFullScan()
            return
        }

        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) == 0 {
            return
        }

        let url = URL(fileURLWithPath: path)
        guard isImageFile(url) else { return }

        let created = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
        let removed = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0
        let modified = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0
        let renamed = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0

        if created {
            let filename = url.lastPathComponent
            knownFiles.insert(filename)
            updateAttributes(directory: url.deletingLastPathComponent().path, filename: filename)
            callbackQueue.async { [weak self] in
                self?.onFileCreated?(url)
            }
        }

        if removed {
            let filename = url.lastPathComponent
            knownFiles.remove(filename)
            knownModificationDates.removeValue(forKey: filename)
            knownSizes.removeValue(forKey: filename)
            callbackQueue.async { [weak self] in
                self?.onFileDeleted?(url)
            }
        }

        if modified || renamed {
            let filename = url.lastPathComponent
            let changed = didAttributesChange(directory: url.deletingLastPathComponent().path, filename: filename)
            if changed {
                updateAttributes(directory: url.deletingLastPathComponent().path, filename: filename)
                callbackQueue.async { [weak self] in
                    self?.onFileModified?(url)
                }
            }
        }
    }

    private func isImageFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }

    private func performFullScan() {
        guard let directory = monitoredDirectory else { return }
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { return }

        let currentImageFiles = Set(contents.filter { filename in
            let path = (directory as NSString).appendingPathComponent(filename)
            return isImageFile(URL(fileURLWithPath: path))
        })

        let newFiles = currentImageFiles.subtracting(knownFiles)
        for filename in newFiles {
            let path = (directory as NSString).appendingPathComponent(filename)
            let fileURL = URL(fileURLWithPath: path)
            callbackQueue.async { [weak self] in
                self?.onFileCreated?(fileURL)
            }
        }

        let deletedFiles = knownFiles.subtracting(currentImageFiles)
        for filename in deletedFiles {
            let path = (directory as NSString).appendingPathComponent(filename)
            let fileURL = URL(fileURLWithPath: path)
            callbackQueue.async { [weak self] in
                self?.onFileDeleted?(fileURL)
            }
        }

        knownFiles = currentImageFiles
        knownModificationDates = loadModificationDates(directory: directory, filenames: Array(currentImageFiles))
        knownSizes = loadSizes(directory: directory, filenames: Array(currentImageFiles))
    }

    private func updateAttributes(directory: String, filename: String) {
        let path = (directory as NSString).appendingPathComponent(filename)
        if let attrs = try? fileManager.attributesOfItem(atPath: path) {
            if let modified = attrs[.modificationDate] as? Date {
                knownModificationDates[filename] = modified
            }
            if let size = attrs[.size] as? NSNumber {
                knownSizes[filename] = size.int64Value
            }
        }
    }

    private func didAttributesChange(directory: String, filename: String) -> Bool {
        let path = (directory as NSString).appendingPathComponent(filename)
        guard let attrs = try? fileManager.attributesOfItem(atPath: path) else {
            return false
        }
        let previousDate = knownModificationDates[filename]
        let previousSize = knownSizes[filename]
        let currentDate = attrs[.modificationDate] as? Date
        let currentSize = (attrs[.size] as? NSNumber)?.int64Value
        let dateChanged = previousDate != nil && currentDate != nil && currentDate! > previousDate!
        let sizeChanged = previousSize != nil && currentSize != nil && currentSize! != previousSize!
        return dateChanged || sizeChanged
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

    private func loadSizes(directory: String, filenames: [String]) -> [String: Int64] {
        var results: [String: Int64] = [:]
        for filename in filenames {
            let path = (directory as NSString).appendingPathComponent(filename)
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? NSNumber {
                results[filename] = size.int64Value
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
