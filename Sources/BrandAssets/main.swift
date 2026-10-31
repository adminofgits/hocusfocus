import AppKit
import HocusFocusBrand

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: BrandAssets <project-directory>\n", stderr)
    exit(2)
}
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assets = root.appendingPathComponent("asset", isDirectory: true)
let output = root.appendingPathComponent(".build/branding", isDirectory: true)
let iconset = output.appendingPathComponent("HocusFocus.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try BrandArtwork.svg(dark: true, banner: true).write(to: assets.appendingPathComponent("logo-dark.svg"), atomically: true, encoding: .utf8)
try BrandArtwork.svg(dark: false, banner: true).write(to: assets.appendingPathComponent("logo-light.svg"), atomically: true, encoding: .utf8)
try BrandArtwork.svg(dark: true, banner: false).write(to: assets.appendingPathComponent("mark.svg"), atomically: true, encoding: .utf8)
let icon = BrandArtwork.appIcon()
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try BrandArtwork.png(icon, pixels: size * scale)
            .write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
try BrandArtwork.png(icon, pixels: 512).write(to: output.appendingPathComponent("app-icon.png"))
try BrandArtwork.png(BrandArtwork.mark(size: 128), pixels: 256).write(to: output.appendingPathComponent("mark.png"))
print("Generated HocusFocus logos and app icon.")
