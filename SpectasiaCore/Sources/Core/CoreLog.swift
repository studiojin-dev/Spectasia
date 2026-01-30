import Foundation
import os.log

public enum CoreLog {
    private static let subsystem = "com.spectasia.core"

    public static func error(_ message: String, category: String) {
        log(message, category: category, type: .error)
    }

    public static func warning(_ message: String, category: String) {
        log(message, category: category, type: .default)
    }

    public static func info(_ message: String, category: String) {
        log(message, category: category, type: .info)
    }

    public static func debug(_ message: String, category: String) {
        log(message, category: category, type: .debug)
    }

    private static func log(_ message: String, category: String, type: OSLogType) {
        if #available(macOS 11.0, *) {
            Logger(subsystem: subsystem, category: category).log(level: type, "\(message, privacy: .public)")
        } else {
            os_log("%{public}@", log: OSLog(subsystem: subsystem, category: category), type: type, message)
        }
    }
}
