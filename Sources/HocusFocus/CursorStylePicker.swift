import AppKit
import HocusFocusCore
import HocusFocusBrand
import SwiftUI

struct CursorStylePicker: View {
    @Binding var selection: Configuration.Feedback.CursorStyle
    private let accent = Color(nsColor: Brand.Palette.accent.nsColor)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Cursor accent").font(.system(size: 11, weight: .medium))
            HStack(spacing: 7) {
                ForEach(Configuration.Feedback.CursorStyle.allCases, id: \.self) { style in
                    CursorStyleTile(style: style, selected: selection == style, accent: accent) {
                        selection = style
                    }
                }
            }
            Text("Preview a style above. Off keeps focus follows mouse enabled.")
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private final class CursorPreviewState: ObservableObject {
    @Published var replay = 0
}

private struct CursorStyleTile: View {
    let style: Configuration.Feedback.CursorStyle
    let selected: Bool
    let accent: Color
    let select: () -> Void
    @StateObject private var preview = CursorPreviewState()

    var body: some View {
        Button {
            preview.replay += 1
            select()
        } label: {
            VStack(spacing: 3) {
                CursorAccentPreview(style: style, replay: preview.replay).frame(height: 38)
                    .allowsHitTesting(false).accessibilityHidden(true)
                Text(style.rawValue.capitalized).font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .background(selected ? accent.opacity(0.15) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? accent.opacity(0.5) : .clear))
            .foregroundStyle(selected ? accent : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { if $0 { preview.replay += 1 } }
        .accessibilityLabel("Cursor accent: \(style.rawValue.capitalized)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .help(style == .off ? "Disable cursor effects" : "Preview \(style.rawValue); click to select")
    }
}

private struct CursorAccentPreview: NSViewRepresentable {
    let style: Configuration.Feedback.CursorStyle
    let replay: Int

    func makeNSView(context: Context) -> CursorPreviewView { CursorPreviewView() }
    func updateNSView(_ view: CursorPreviewView, context: Context) {
        view.update(style: style, replay: replay)
    }
}

private final class CursorPreviewView: NSView {
    private let effect = FocusAccentView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
    private var lastReplay: Int?
    private var lastStyle: Configuration.Feedback.CursorStyle?

    init() {
        super.init(frame: .zero)
        addSubview(effect)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout()
        effect.setFrameOrigin(NSPoint(x: hotspot.x - 14, y: hotspot.y - 14))
    }
    private var hotspot: NSPoint { NSPoint(x: bounds.midX - 4, y: bounds.midY + 4) }

    override func draw(_ dirtyRect: NSRect) {
        let cursor = NSCursor.arrow
        let size = cursor.image.size
        let scale = 22 / max(size.height, 1)
        // Fit the cursor inside the tile and anchor the accent at its hotspot.
        cursor.image.draw(in: NSRect(x: hotspot.x - cursor.hotSpot.x * scale,
                                    y: hotspot.y - (size.height - cursor.hotSpot.y) * scale,
                                    width: size.width * scale, height: size.height * scale))
    }
    func update(style: Configuration.Feedback.CursorStyle, replay: Int) {
        guard replay != lastReplay || style != lastStyle else { return }
        lastReplay = replay
        lastStyle = style
        effect.play(style: style, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}
