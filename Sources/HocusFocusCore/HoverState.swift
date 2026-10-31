/// Uses monotonic timestamps supplied by the caller. Window identity includes the
/// process and window ID so two windows in the same application stay distinct.
public struct WindowIdentity: Equatable {
    public let processID: Int32
    public let windowID: UInt32
    public init(processID: Int32, windowID: UInt32) {
        self.processID = processID
        self.windowID = windowID
    }
}

public struct HoverState {
    public enum Update: Equatable {
        case idle
        case waiting(progress: Double, remaining: Double)
        case focus(WindowIdentity)
    }

    private var target: WindowIdentity?
    private var enteredAt: Double = 0
    private var completed = false
    public init() {}

    public mutating func reset() {
        target = nil
        completed = false
    }

    public mutating func update(target candidate: WindowIdentity?, now: Double, delay: Double) -> Update {
        guard let candidate else {
            reset()
            return .idle
        }
        if candidate != target {
            target = candidate
            enteredAt = now
            completed = false
        }
        guard !completed else { return .idle }
        let elapsed = max(0, now - enteredAt)
        if elapsed >= delay {
            completed = true
            return .focus(candidate)
        }
        return .waiting(progress: elapsed / delay, remaining: delay - elapsed)
    }
}
