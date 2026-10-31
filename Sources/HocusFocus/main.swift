import AppKit
import HocusFocusCore

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--check-config" {
    guard arguments.count <= 2 else {
        fputs("Usage: HocusFocus --check-config [path]\n", stderr)
        exit(2)
    }
    let path = arguments.count == 2 ? arguments[1] : ConfigLocation.url.path
    do {
        let config = try Configuration.parse(String(contentsOfFile: path, encoding: .utf8))
        print("Valid configuration: \(config.focus.delayMS) ms delay; app mode: \(config.apps.mode.rawValue)")
        exit(0)
    } catch {
        fputs("Configuration error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else if !arguments.isEmpty {
    print("HocusFocus: a macOS menu bar app for focus follows mouse.\nUsage: HocusFocus [--check-config [path]]")
    exit(arguments == ["--help"] ? 0 : 2)
}

let app = NSApplication.shared
// Keep the delegate alive for the lifetime of the application.
let delegate = AppDelegate()
app.delegate = delegate
app.run()
