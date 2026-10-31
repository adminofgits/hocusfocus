import AppKit
import QuartzCore
import Testing
import HocusFocusCore
@testable import HocusFocus

struct PointerFeedbackTests {
    @MainActor @Test func offCancelsAnExistingEffect() {
        let view = FocusAccentView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        view.play(style: .sweep, reduceMotion: false)
        let previous = view.effectLayers.first
        #expect(previous?.animation(forKey: "focusAccent") != nil)
        view.play(style: .off, reduceMotion: false)
        #expect(view.effectLayers.isEmpty)
        #expect(previous?.superlayer == nil)
        #expect(previous?.animationKeys()?.isEmpty ?? true)
    }

    @MainActor @Test func reducedMotionRemovesMovementForEveryStyle() throws {
        let view = FocusAccentView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        for style in Configuration.Feedback.CursorStyle.allCases where style != .off {
            view.play(style: style, reduceMotion: true)
            let layer = try #require(view.effectLayers.first)
            let group = try #require(layer.animation(forKey: "focusAccent") as? CAAnimationGroup)
            #expect(group.animations?.count == 1)
            #expect((group.animations?.first as? CAPropertyAnimation)?.keyPath == "opacity")
            #expect(layer.opacity == 0) // Nothing remains visible after the animation.
            #expect(view.hitTest(.zero) == nil) // Previews cannot intercept tile clicks.
        }
    }

    @MainActor @Test func repeatedPreviewsReplacePreviousLayers() {
        let view = FocusAccentView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        for _ in 0..<5 {
            for style in [Configuration.Feedback.CursorStyle.sweep, .glow, .spark] {
                view.play(style: style, reduceMotion: false)
                #expect(view.effectLayers.count == 1)
                #expect(view.layer?.sublayers?.count == 1)
            }
        }
        view.stop()
        #expect(view.layer?.sublayers?.isEmpty ?? true)
    }
}
