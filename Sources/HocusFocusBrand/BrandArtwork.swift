import AppKit
import HocusFocusCore

public extension Brand.RGB {
    var nsColor: NSColor {
        NSColor(srgbRed: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, alpha: 1)
    }
}

/// An original focus spark held by two offset window frames.
/// These paths drive the menu bar, panel, app icon, and README SVGs.
public enum BrandArtwork {
    private enum Segment {
        case move(Double, Double), line(Double, Double)
        case curve(Double, Double, Double, Double, Double, Double)
        case close
    }
    private static let outer: [[Segment]] = [
        [.move(27, 8), .line(17, 8), .curve(12, 8, 8, 12, 8, 17), .line(8, 27)],
        [.move(37, 56), .line(47, 56), .curve(52, 56, 56, 52, 56, 47), .line(56, 37)],
    ]
    private static let inner: [[Segment]] = [
        [.move(38, 16), .line(45, 16), .curve(47, 16, 48, 17, 48, 19), .line(48, 26)],
        [.move(16, 38), .line(16, 45), .curve(16, 47, 17, 48, 19, 48), .line(26, 48)],
    ]
    private static let spark: [Segment] = [
        .move(32, 19), .line(35.5, 28.5), .line(45, 32), .line(35.5, 35.5),
        .line(32, 45), .line(28.5, 35.5), .line(19, 32), .line(28.5, 28.5), .close,
    ]

    public static func mark(size: CGFloat = 18, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            drawMark(in: rect, primary: template ? .black : Brand.Palette.accent.nsColor,
                     secondary: template ? .black : Brand.Palette.highlight.nsColor)
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "HocusFocus focus spark"
        return image
    }

    public static func drawMark(in rect: CGRect, primary: NSColor, secondary: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = AffineTransform(translationByX: rect.minX, byY: rect.minY)
        (transform as NSAffineTransform).concat()
        let scale = AffineTransform(scaleByX: rect.width / 64, byY: rect.height / 64)
        (scale as NSAffineTransform).concat()
        primary.setStroke()
        for segments in outer + inner {
            let path = bezier(segments)
            path.lineWidth = 5.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
        secondary.setFill()
        bezier(spark).fill()
    }

    public static func appIcon() -> NSImage {
        NSImage(size: NSSize(width: 1024, height: 1024), flipped: true) { _ in
            let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 196, yRadius: 196)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = .black.withAlphaComponent(0.28)
            shadow.shadowBlurRadius = 30
            shadow.shadowOffset = NSSize(width: 0, height: 12)
            shadow.set()
            Brand.Palette.background.nsColor.setFill()
            tile.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.11, blue: 0.34, alpha: 1),
                       ending: Brand.Palette.background.nsColor)?.draw(in: tile, angle: 65)
            Brand.Palette.accent.nsColor.withAlphaComponent(0.25).setStroke()
            let rim = NSBezierPath(roundedRect: NSRect(x: 90, y: 90, width: 844, height: 844), xRadius: 188, yRadius: 188)
            rim.lineWidth = 3
            rim.stroke()
            drawMark(in: CGRect(x: 218, y: 218, width: 588, height: 588),
                     primary: Brand.Palette.accent.nsColor, secondary: Brand.Palette.highlight.nsColor)
            return true
        }
    }

    public static func png(_ image: NSImage, pixels: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.coderInvalidValue)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.coderInvalidValue) }
        return data
    }

    public static func svg(dark: Bool, banner: Bool) -> String {
        let primary = dark ? Brand.Palette.accent.hex : Brand.Palette.deep.hex
        let secondary = dark ? Brand.Palette.highlight.hex : Brand.Palette.deep.hex
        var shapes = ""
        for segments in outer + inner {
            shapes += "<path d=\"\(svgPath(segments))\" fill=\"none\" stroke=\"\(primary)\" stroke-width=\"5.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n"
        }
        shapes += "<path d=\"\(svgPath(spark))\" fill=\"\(secondary)\"/>\n"
        if banner {
            shapes = "<g transform=\"translate(8 8) scale(1.5)\">\n\(shapes)</g>\n"
            let blocks: [(Character, [(Int, Int)])] = [
                ("█", [(0, 2)]), ("▀", [(0, 1)]), ("▄", [(1, 1)]), ("░", [(0, 2)]),
            ]
            for (row, line) in [Brand.top, Brand.bottom].enumerated() {
                for (column, character) in line.enumerated() {
                    guard let spans = blocks.first(where: { $0.0 == character })?.1 else { continue }
                    for (offset, height) in spans {
                        let color = row == 0 ? (dark ? "#8B839F" : "#81758F") : primary
                        shapes += "<rect x=\"\(128 + column * 12)\" y=\"\(24 + row * 32 + offset * 16)\" width=\"12\" height=\"\(height * 16)\" fill=\"\(color)\"\(character == "░" ? " opacity=\"0.22\"" : "")/>\n"
                    }
                }
            }
        }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(banner ? "584 112" : "64 64")" role="img" aria-label="HocusFocus">
        <title>HocusFocus</title>
        \(shapes)</svg>

        """
    }

    private static func bezier(_ segments: [Segment]) -> NSBezierPath {
        let path = NSBezierPath()
        for segment in segments {
            switch segment {
            case .move(let x, let y): path.move(to: NSPoint(x: x, y: y))
            case .line(let x, let y): path.line(to: NSPoint(x: x, y: y))
            case .curve(let x1, let y1, let x2, let y2, let x, let y):
                path.curve(to: NSPoint(x: x, y: y), controlPoint1: NSPoint(x: x1, y: y1), controlPoint2: NSPoint(x: x2, y: y2))
            case .close: path.close()
            }
        }
        return path
    }

    private static func svgPath(_ segments: [Segment]) -> String {
        segments.map { segment in
            switch segment {
            case .move(let x, let y): return "M\(x) \(y)"
            case .line(let x, let y): return "L\(x) \(y)"
            case .curve(let x1, let y1, let x2, let y2, let x, let y): return "C\(x1) \(y1) \(x2) \(y2) \(x) \(y)"
            case .close: return "Z"
            }
        }.joined(separator: " ")
    }
}
