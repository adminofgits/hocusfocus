import Testing
@testable import HocusFocusCore

final class HoverStateTests {
    let first = WindowIdentity(processID: 42, windowID: 1)
    let second = WindowIdentity(processID: 42, windowID: 2)

    @Test func testFocusAfterDelayAndOnlyOnce() {
        var hover = HoverState()
        #expect(hover.update(target: first, now: 10, delay: 0.5) == .waiting(progress: 0, remaining: 0.5))
        #expect(hover.update(target: first, now: 10.25, delay: 0.5) == .waiting(progress: 0.5, remaining: 0.25))
        #expect(hover.update(target: first, now: 10.5, delay: 0.5) == .focus(first))
        #expect(hover.update(target: first, now: 11, delay: 0.5) == .idle)
    }

    @Test func testAnotherWindowInSameAppRestartsTimer() {
        var hover = HoverState()
        _ = hover.update(target: first, now: 0, delay: 1)
        #expect(hover.update(target: second, now: 0.75, delay: 1) == .waiting(progress: 0, remaining: 1))
        #expect(hover.update(target: second, now: 1.25, delay: 1) == .waiting(progress: 0.5, remaining: 0.5))
        #expect(hover.update(target: second, now: 2, delay: 1) == .focus(second))
    }

    @Test func testLeavingOrPausingCancelsPendingFocus() {
        var hover = HoverState()
        _ = hover.update(target: first, now: 0, delay: 1)
        #expect(hover.update(target: nil, now: 0.9, delay: 1) == .idle)
        #expect(hover.update(target: first, now: 2, delay: 1) == .waiting(progress: 0, remaining: 1))
        hover.reset()
        #expect(hover.update(target: first, now: 3, delay: 1) == .waiting(progress: 0, remaining: 1))
    }

    @Test func testZeroDelayFocusesImmediately() {
        var hover = HoverState()
        #expect(hover.update(target: first, now: 0, delay: 0) == .focus(first))
        #expect(hover.update(target: first, now: 1, delay: 0) == .idle)
        #expect(hover.update(target: second, now: 1, delay: 0) == .focus(second))
    }

    @Test func testReturningToAWindowAllowsFocusAgain() {
        var hover = HoverState()
        _ = hover.update(target: first, now: 0, delay: 0)
        _ = hover.update(target: second, now: 1, delay: 0)
        #expect(hover.update(target: first, now: 2, delay: 0) == .focus(first))
    }
}
