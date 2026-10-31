import AppKit
import HocusFocusCore

enum ClientError: LocalizedError {
    case notRunning
    case message(String)
    var errorDescription: String? {
        switch self {
        case .notRunning: return "HocusFocus is not running. Run 'just run' from a checkout or 'hocusfocus start' for the packaged app."
        case .message(let text): return text
        }
    }
}

final class AppClient: NSObject {
    private var response: RuntimeStatus?

    var runningApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: AppControl.bundleID).first
    }

    func send(_ command: String) throws -> RuntimeStatus {
        response = nil
        let requestID = UUID().uuidString
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(receive(_:)), name: NSNotification.Name(AppControl.responseNotification), object: requestID)
        defer { center.removeObserver(self) }
        center.postNotificationName(
            NSNotification.Name(AppControl.requestNotification), object: AppControl.bundleID,
            userInfo: ["id": requestID, "command": command], deliverImmediately: true
        )
        let deadline = Date().addingTimeInterval(3)
        while response == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        guard let response else {
            if runningApp == nil { throw ClientError.notRunning }
            throw ClientError.message("The menu bar app did not respond within 3 seconds.")
        }
        if let error = response.error, command != "status" { throw ClientError.message(error) }
        return response
    }

    @objc private func receive(_ notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? String,
              let value = try? JSONDecoder().decode(RuntimeStatus.self, from: Data(payload.utf8)) else { return }
        response = value
    }

    func launch(path: String?) throws {
        if runningApp != nil { return }
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let candidates = path.map { [URL(fileURLWithPath: $0)] } ?? [
            URL(fileURLWithPath: "/Applications/HocusFocus.app"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/HocusFocus.app"),
            executable.deletingLastPathComponent().appendingPathComponent("HocusFocus.app"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("dist/HocusFocus.app"),
        ]
        guard let bundle = candidates.first(where: { Bundle(url: $0)?.bundleIdentifier == AppControl.bundleID }) else {
            throw ClientError.message("HocusFocus.app was not found. Build it with 'just build', or use 'start --app /path/to/HocusFocus.app'.")
        }
        var finished = false
        var launchError: Error?
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: bundle, configuration: configuration) { _, error in
            launchError = error
            finished = true
        }
        let deadline = Date().addingTimeInterval(10)
        while !finished && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        if let launchError { throw launchError }
        guard finished else { throw ClientError.message("Timed out while launching HocusFocus.app.") }
    }
}
