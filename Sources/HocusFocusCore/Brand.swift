import Foundation

/// HocusFocus's block lettering and shared violet palette.
public enum Brand {
    public static let top = "█░█ █▀█ █▀▀ █░█ █▀ █▀▀ █▀█ █▀▀ █░█ █▀"
    public static let bottom = "█▀█ █▄█ █▄▄ █▄█ ▄█ █▀░ █▄█ █▄▄ █▄█ ▄█"

    public struct RGB {
        public let red: Int
        public let green: Int
        public let blue: Int
        public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
        fileprivate var ansi: String { "38;2;\(red);\(green);\(blue)" }
    }

    public enum Palette {
        public static let accent = RGB(red: 183, green: 140, blue: 255)
        public static let highlight = RGB(red: 225, green: 210, blue: 255)
        public static let deep = RGB(red: 117, green: 66, blue: 203)
        public static let background = RGB(red: 17, green: 16, blue: 27)
        public static let error = RGB(red: 240, green: 128, blue: 160)
        public static let info = RGB(red: 159, green: 166, blue: 255)
    }
}

public enum ColorMode: String, CaseIterable { case auto, always, never }

/// Shared semantic roles keep commands independent of ANSI escape sequences.
public struct TerminalStyle {
    public enum Role { case mute, accent, ok, error, info }
    public let color: Bool

    public init(mode: ColorMode, isTTY: Bool, environment: [String: String]) {
        switch mode {
        case .always: color = true
        case .never: color = false
        case .auto: color = isTTY && environment["NO_COLOR"] == nil && environment["TERM"] != "dumb"
        }
    }

    public func paint(_ text: String, _ role: Role) -> String {
        guard color else { return text }
        let code: String
        switch role {
        case .mute: code = "2"
        case .accent: code = Brand.Palette.accent.ansi
        case .ok: code = Brand.Palette.highlight.ansi
        case .error: code = Brand.Palette.error.ansi
        case .info: code = Brand.Palette.info.ansi
        }
        return "\u{1B}[\(code)m\(text)\u{1B}[0m"
    }

    public var banner: String { "  \(paint(Brand.top, .mute))\n  \(paint(Brand.bottom, .accent))\n" }

    /// Keep Argument Parser's generated help as the source of commands/flags.
    public func help(_ generated: String, root: Bool) -> String {
        let lines = generated.split(separator: "\n", omittingEmptySubsequences: false).map { raw -> String in
            let line = String(raw)
            if line.isEmpty { return "" }
            if line.first != " " && line.contains(":") {
                let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                return "  " + paint(String(parts[0]).lowercased(), .accent) +
                    (parts[1].isEmpty ? "" : "\n  " + String(parts[1]).trimmingCharacters(in: .whitespaces))
            }
            if line.hasPrefix("  "), let split = line.range(of: "  ", range: line.index(line.startIndex, offsetBy: 2)..<line.endIndex) {
                let name = String(line[..<split.lowerBound])
                let rest = String(line[split.lowerBound...])
                return "  " + paint(name, .accent) + paint(rest, .mute)
            }
            return "  " + paint(line, .mute)
        }
        return "\n" + (root ? banner + "\n" : "") + lines.joined(separator: "\n") + "\n"
    }
}
