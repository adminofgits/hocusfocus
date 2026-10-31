import CoreGraphics
import Testing
@testable import HocusFocus

struct WindowOcclusionTests {
    private let desktop = CGRect(x: 0, y: 0, width: 5120, height: 1440)

    @Test func transparentDesktopNotificationHostDoesNotHideGhostty() {
        #expect(WindowOcclusion.isPassThroughOverlay(
            bundleID: "com.apple.notificationcenterui", bounds: desktop, desktopBounds: desktop,
            processID: 10, hitProcessID: 20))
        #expect(WindowOcclusion.isPassThroughOverlay(
            bundleID: "com.apple.notificationcenterui", bounds: desktop, desktopBounds: desktop,
            processID: 10, hitProcessID: nil))
    }

    @Test func interactiveNotificationStillBlocksFocusBehindIt() {
        #expect(!WindowOcclusion.isPassThroughOverlay(
            bundleID: "com.apple.notificationcenterui", bounds: desktop, desktopBounds: desktop,
            processID: 10, hitProcessID: 10))
    }

    @Test func boundedBannerWithUnknownHitTargetStillBlocksFocus() {
        #expect(!WindowOcclusion.isPassThroughOverlay(
            bundleID: "com.apple.notificationcenterui", bounds: CGRect(x: 4500, y: 20, width: 400, height: 100),
            desktopBounds: desktop, processID: 10, hitProcessID: nil))
    }

    @Test func otherAppsAndMenusAreNotTreatedAsNotificationOverlays() {
        #expect(!WindowOcclusion.isPassThroughOverlay(
            bundleID: "com.example.floating-panel", bounds: desktop, desktopBounds: desktop,
            processID: 10, hitProcessID: 20))
        #expect(!WindowOcclusion.isPassThroughOverlay(
            bundleID: "com.apple.notificationcenterui", bounds: desktop, desktopBounds: .null,
            processID: 10, hitProcessID: nil))
    }
}
