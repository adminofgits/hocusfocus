import Carbon
import Testing
@testable import HocusFocus

struct NonRaisingFocusTests {
    @Test func switchingAppsUsesOnlyNonRaisingActivation() {
        var events: [[UInt8]] = []
        var modes: [UInt32] = []
        let focus = NonRaisingFocus(
            lookup: { _, _ in noErr },
            activate: { _, id, mode in
                #expect(id == 0x12345678)
                modes.append(mode)
                return .success
            },
            post: { _, pointer in
                events.append(Array(UnsafeBufferPointer(start: pointer, count: 0xf8)))
                return .success
            }, pause: { Issue.record("Switching apps should not pause for a same-app handoff") })
        #expect(focus.focus(processID: 42, windowID: 0x12345678, previousWindowID: nil))
        #expect(modes == [0x200])
        #expect(events.count == 2)
        #expect(events.map { $0[8] } == [1, 2])
        #expect(events.allSatisfy { Array($0[0x3c..<0x40]) == [0x78, 0x56, 0x34, 0x12] })
        #expect(events.allSatisfy { $0[0x3a] == 0x10 && $0.count == 0xf8 })
    }

    @Test func sameAppHandsOffTheOldWindowBeforeSelectingTheNewOne() {
        var events: [[UInt8]] = []
        var operations: [String] = []
        let focus = NonRaisingFocus(
            lookup: { _, _ in noErr },
            activate: { _, _, _ in operations.append("activate"); return .success },
            post: { _, pointer in
                events.append(Array(UnsafeBufferPointer(start: pointer, count: 0xf8)))
                operations.append("post")
                return .success
            }, pause: { operations.append("pause") })
        #expect(focus.focus(processID: 42, windowID: 20, previousWindowID: 10))
        #expect(operations == ["post", "pause", "post", "activate", "post", "post"])
        #expect(events.map { $0[8] } == [0x0d, 0x0d, 1, 2])
        #expect(events[0][0x8a] == 2)
        #expect(events[0][0x3c] == 10)
        #expect(events[1][0x8a] == 1)
        #expect(events[1][0x3c] == 20)
    }

    @Test func failedLookupDoesNotActivateOrPostEvents() {
        let focus = NonRaisingFocus(
            lookup: { _, _ in -600 },
            activate: { _, _, _ in Issue.record("Must not activate after lookup failure"); return .success },
            post: { _, _ in Issue.record("Must not post after lookup failure"); return .success },
            pause: {})
        #expect(!focus.focus(processID: 42, windowID: 20, previousWindowID: nil))
    }

    @Test func failedActivationDoesNotSendKeyEvents() {
        let focus = NonRaisingFocus(
            lookup: { _, _ in noErr }, activate: { _, _, _ in .failure },
            post: { _, _ in Issue.record("Must not post after activation failure"); return .success },
            pause: {})
        #expect(!focus.focus(processID: 42, windowID: 20, previousWindowID: nil))
    }

    @Test func rejectedEventStopsTheHandoff() {
        var activationCount = 0
        var pauseCount = 0
        let focus = NonRaisingFocus(
            lookup: { _, _ in noErr },
            activate: { _, _, _ in activationCount += 1; return .success },
            post: { _, _ in .failure }, pause: { pauseCount += 1 })
        #expect(!focus.focus(processID: 42, windowID: 20, previousWindowID: 10))
        #expect(activationCount == 0)
        #expect(pauseCount == 0)
    }
}
