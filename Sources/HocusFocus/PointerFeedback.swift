import AppKit
import QuartzCore
import HocusFocusCore
import HocusFocusBrand

/// A brief accent at the pointer hotspot after a focus change.
final class PointerFeedback {
    private let panel: NSPanel
    private let accent: FocusAccentView
    private var hideWork: DispatchWorkItem?

    init() {
        let frame = NSRect(x: 0, y: 0, width: 28, height: 28)
        accent = FocusAccentView(frame: frame)
        panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = accent
        panel.setAccessibilityElement(false)
    }

    func showFocusAccent(style: Configuration.Feedback.CursorStyle) {
        hide()
        guard style != .off else { return }
        let point = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: point.x - 14, y: point.y - 14))
        panel.orderFrontRegardless()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        accent.play(style: style, reduceMotion: reduceMotion)
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + FocusAccentView.playbackDuration(reduceMotion: reduceMotion) + 0.05, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        accent.stop()
        panel.orderOut(nil)
    }
}

/// Shared by the real pointer overlay and the in-panel previews.
final class FocusAccentView: NSView {
    private(set) var effectLayers: [CAShapeLayer] = []

    private static func cycleDuration(reduceMotion: Bool) -> TimeInterval { reduceMotion ? 0.65 : 0.55 }
    static func playbackDuration(reduceMotion: Bool) -> TimeInterval {
        cycleDuration(reduceMotion: reduceMotion) * (reduceMotion ? 1 : 2)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func play(style: Configuration.Feedback.CursorStyle, reduceMotion: Bool) {
        stop()
        guard style != .off else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let shape = CAShapeLayer()
        shape.frame = bounds
        shape.fillColor = nil
        let color = Brand.Palette.accent.nsColor.blended(withFraction: 0.25, of: Brand.Palette.highlight.nsColor)
            ?? Brand.Palette.accent.nsColor
        shape.strokeColor = color.cgColor
        shape.lineWidth = 2.2
        shape.lineCap = .round
        if style == .spark {
            let path = CGMutablePath()
            for index in 0..<4 {
                let angle = CGFloat(index) * .pi / 2
                path.move(to: CGPoint(x: center.x + cos(angle) * 8, y: center.y + sin(angle) * 8))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * 12, y: center.y + sin(angle) * 12))
            }
            shape.path = path
        } else {
            shape.path = CGPath(ellipseIn: bounds.insetBy(dx: 5, dy: 5), transform: nil)
        }
        if style == .glow {
            shape.lineWidth = 2.6
            shape.shadowColor = color.cgColor
            shape.shadowRadius = 3
            shape.shadowOpacity = 0.8
            shape.shadowOffset = .zero
        }
        shape.opacity = 0
        layer?.addSublayer(shape)
        effectLayers = [shape]

        let cycleDuration = Self.cycleDuration(reduceMotion: reduceMotion)
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, style == .glow ? 0.85 : 1, 0.9, 0]
        fade.keyTimes = [0, 0.25, 0.6, 1]
        fade.duration = cycleDuration
        fade.calculationMode = .cubic
        var animations: [CAAnimation] = [fade]
        if !reduceMotion {
            if style == .sweep {
                let draw = CABasicAnimation(keyPath: "strokeEnd")
                draw.fromValue = 0
                draw.toValue = 1
                draw.duration = cycleDuration * 0.56
                draw.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                draw.fillMode = .forwards
                let erase = CABasicAnimation(keyPath: "strokeStart")
                erase.fromValue = 0
                erase.toValue = 1
                erase.beginTime = cycleDuration * 0.32
                erase.duration = cycleDuration * 0.68
                erase.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animations += [draw, erase]
            } else {
                // Scale around the hotspot without moving the overlay or cursor.
                shape.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = style == .spark ? 0.75 : 0.9
                scale.toValue = 1.08
                scale.duration = cycleDuration
                scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animations.append(scale)
            }
        }
        let animation = CAAnimationGroup()
        animation.animations = animations
        animation.duration = cycleDuration
        // Repeat softly, then disappear. Reduce Motion keeps a single static fade.
        animation.repeatCount = reduceMotion ? 1 : 2
        shape.add(animation, forKey: "focusAccent")
    }

    func stop() {
        effectLayers.forEach { $0.removeAllAnimations(); $0.removeFromSuperlayer() }
        effectLayers = []
    }
}
