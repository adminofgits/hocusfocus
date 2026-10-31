import ArgumentParser
import Darwin
import Foundation
import HocusFocusCore

extension ColorMode: ExpressibleByArgument {}

struct OutputOptions: ParsableArguments {
    @Option(help: "Color output: auto, always, or never.")
    var color: ColorMode = .auto

    @Flag(help: "Write machine-readable JSON instead of styled output.")
    var json = false

    var renderer: Output { Output(options: self) }
}

struct Output {
    let options: OutputOptions
    var style: TerminalStyle {
        TerminalStyle(mode: options.color, isTTY: isatty(STDOUT_FILENO) != 0, environment: ProcessInfo.processInfo.environment)
    }

    func section<T: Encodable>(_ title: String, rows: [(String, String)], value: T) throws {
        if options.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.keyEncodingStrategy = .convertToSnakeCase
            print(String(decoding: try encoder.encode(value), as: UTF8.self))
            return
        }
        print("\n  " + style.paint(title, .accent) + "\n")
        let width = rows.map { $0.0.count }.max() ?? 0
        for (key, text) in rows {
            let label = key.padding(toLength: width, withPad: " ", startingAt: 0)
            let role: TerminalStyle.Role = text == "yes" || text == "active" ? .ok : .mute
            print("  \(style.paint(label, .accent))  \(style.paint(text, role))")
        }
        print()
    }

    func status(_ value: RuntimeStatus, title: String = "HocusFocus") throws {
        try section(title, rows: [
            ("running", value.running ? "yes" : "no"),
            ("focus", value.running ? (value.enabled ? "active" : "paused") : "stopped"),
            ("accessibility", value.accessibility ? "yes" : "permission needed"),
            ("hover delay", "\(value.delayMS) ms"),
            ("configuration", value.configPath),
        ] + (value.focusState.map { [("hover state", $0)] } ?? [])
          + (value.error.map { [("error", $0)] } ?? []), value: value)
    }
}
