import ArgumentParser
import Darwin
import Foundation
import HocusFocusCore

do {
    var command = try HocusFocusCommand.parseAsRoot()
    try command.run()
} catch {
    let code = HocusFocusCommand.exitCode(for: error)
    let message = HocusFocusCommand.fullMessage(for: error)
    let arguments = Array(CommandLine.arguments.dropFirst())
    let colorIndex = arguments.lastIndex(of: "--color")
    let colorValue = colorIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        ?? arguments.last(where: { $0.hasPrefix("--color=") }).map { String($0.dropFirst(8)) }
    let mode = colorValue.flatMap(ColorMode.init(rawValue:)) ?? .auto
    let success = code == .success
    let style = TerminalStyle(mode: mode, isTTY: isatty(success ? STDOUT_FILENO : STDERR_FILENO) != 0, environment: ProcessInfo.processInfo.environment)
    let text: String
    if success && message.contains("USAGE:") {
        let isRoot = !message.contains("USAGE: hocusfocus ") || message.contains("USAGE: hocusfocus [") || message.contains("USAGE: hocusfocus <")
        text = style.help(message, root: isRoot)
    } else if success {
        text = message + "\n"
    } else {
        text = "\n  " + style.paint("✗ ", .error) + style.paint(message, .error) + "\n\n"
    }
    (success ? FileHandle.standardOutput : FileHandle.standardError).write(Data(text.utf8))
    HocusFocusCommand.exit(withError: ExitCode(code.rawValue))
}
