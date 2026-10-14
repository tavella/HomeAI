import Foundation
import os

/// Unified Logging System wrapper using Apple's `os.Logger`.
/// Configures sensitive runtime traces to `.debug` / `.private` so secrets are never dumped to device console logs.
public enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.homeai.app"
    
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let security = Logger(subsystem: subsystem, category: "security")
    public static let storage = Logger(subsystem: subsystem, category: "storage")
    public static let export = Logger(subsystem: subsystem, category: "export")
    public static let chat = Logger(subsystem: subsystem, category: "chat")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
}
