import Foundation

public enum AppControl {
    public static let bundleID = "io.bitsugar.hocusfocus"
    public static let requestNotification = "\(bundleID).control"
    public static let responseNotification = "\(bundleID).response"
}

public struct RuntimeStatus: Codable {
    public let processID: Int32?
    public let running: Bool
    public let enabled: Bool
    public let accessibility: Bool
    public let delayMS: Int
    public let configPath: String
    public let error: String?
    public let focusState: String?

    public init(running: Bool, enabled: Bool, accessibility: Bool, delayMS: Int, configPath: String, error: String?, processID: Int32? = nil, focusState: String? = nil) {
        self.processID = processID
        self.running = running
        self.enabled = enabled
        self.accessibility = accessibility
        self.delayMS = delayMS
        self.configPath = configPath
        self.error = error
        self.focusState = focusState
    }
}

public enum ConfigLocation {
    public static var url: URL {
        let environment = ProcessInfo.processInfo.environment
        let base: URL
        if let xdg = environment["XDG_CONFIG_HOME"], xdg.hasPrefix("/") {
            base = URL(fileURLWithPath: xdg, isDirectory: true)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        }
        return base.appendingPathComponent("hocusfocus/config.toml")
    }
}
