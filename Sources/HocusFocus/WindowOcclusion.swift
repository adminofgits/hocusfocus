import CoreGraphics

/// Notification Center can keep a transparent host window across the desktop.
/// Its CG bounds alone do not mean it owns the UI under the pointer.
enum WindowOcclusion {
    static func isPassThroughOverlay(bundleID: String?, bounds: CGRect, desktopBounds: CGRect,
                                     processID: Int32, hitProcessID: Int32?) -> Bool {
        guard bundleID == "com.apple.notificationcenterui" else { return false }
        if let hitProcessID { return hitProcessID != processID }
        // If hit testing has no answer, only ignore the known desktop-sized
        // host. A bounded notification/banner must still block focus behind it.
        return !desktopBounds.isEmpty && bounds.contains(desktopBounds)
    }
}
