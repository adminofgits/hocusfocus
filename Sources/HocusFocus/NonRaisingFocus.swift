import AppKit
import Carbon
import Darwin

/// Private WindowServer activation protocol, adapted from yabai (MIT).
/// See Resources/Yabai-LICENSE.txt. Never fall back to regular activation here.
struct NonRaisingFocus {
    typealias Lookup = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    typealias Activate = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UInt32, UInt32) -> CGError
    typealias Post = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let hiServices = dlopen("/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices", RTLD_LAZY)

    static let shared: NonRaisingFocus? = {
        guard let skyLight, let hiServices,
              let lookupSymbol = dlsym(hiServices, "GetProcessForPID"),
              let activateSymbol = dlsym(skyLight, "_SLPSSetFrontProcessWithOptions"),
              let postSymbol = dlsym(skyLight, "SLPSPostEventRecordTo") else { return nil }
        let lookup = unsafeBitCast(lookupSymbol, to: Lookup.self)
        let activate = unsafeBitCast(activateSymbol, to: Activate.self)
        let post = unsafeBitCast(postSymbol, to: Post.self)
        return NonRaisingFocus(lookup: { lookup($0, $1) }, activate: { activate($0, $1, $2) },
                               post: { post($0, $1) }, pause: { usleep(40_000) })
    }()

    // Injectable operations let tests verify the protocol without focusing windows.
    var lookup: (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    var activate: (UnsafeMutablePointer<ProcessSerialNumber>, UInt32, UInt32) -> CGError
    var post: (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    var pause: () -> Void

    func focus(processID: pid_t, windowID: UInt32, previousWindowID: UInt32?) -> Bool {
        var process = ProcessSerialNumber()
        guard lookup(processID, &process) == noErr else { return false }
        if let previousWindowID, previousWindowID != windowID {
            guard send(Self.selectionEvent(windowID: previousWindowID, phase: 2), to: &process) else { return false }
            // Some apps need distinct old-window/new-window selection events.
            pause()
            guard send(Self.selectionEvent(windowID: windowID, phase: 1), to: &process) else { return false }
        }
        guard activate(&process, windowID, 0x200) == .success else { return false }
        return send(Self.keyEvent(windowID: windowID, phase: 1), to: &process)
            && send(Self.keyEvent(windowID: windowID, phase: 2), to: &process)
    }

    private func send(_ event: [UInt8], to process: inout ProcessSerialNumber) -> Bool {
        var bytes = event
        return bytes.withUnsafeMutableBufferPointer { post(&process, $0.baseAddress!) == .success }
    }

    static func selectionEvent(windowID: UInt32, phase: UInt8) -> [UInt8] {
        var bytes = event(windowID: windowID)
        bytes[8] = 0x0d
        bytes[0x8a] = phase
        return bytes
    }

    static func keyEvent(windowID: UInt32, phase: UInt8) -> [UInt8] {
        var bytes = event(windowID: windowID)
        bytes[8] = phase
        bytes[0x3a] = 0x10
        bytes.replaceSubrange(0x20..<0x30, with: repeatElement(UInt8(0xff), count: 16))
        return bytes
    }

    private static func event(windowID: UInt32) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[4] = 0xf8
        withUnsafeBytes(of: windowID.littleEndian) { bytes.replaceSubrange(0x3c..<0x40, with: $0) }
        return bytes
    }
}
