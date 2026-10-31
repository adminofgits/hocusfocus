import Foundation
import Testing
@testable import HocusFocusCore

struct AppIdentityTests {
    @Test func appBundleAndCLIUseTheSameIdentity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["CFBundleIdentifier"] as? String == AppControl.bundleID)
        #expect(AppControl.requestNotification == "\(AppControl.bundleID).control")
        #expect(AppControl.responseNotification == "\(AppControl.bundleID).response")
        let script = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        #expect(script.contains("--identifier \(AppControl.bundleID)"))
        let recipes = try String(contentsOf: root.appendingPathComponent("justfile"), encoding: .utf8)
        #expect(recipes.contains("tccutil reset Accessibility \(AppControl.bundleID)"))
    }
}
