import Foundation
import ServiceManagement
import Testing
@testable import HocusFocus

struct LoginItemTests {
    @Test func reflectsSystemChangesAndDoesNotRegisterOnInitialization() {
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service)
        #expect(!controller.isEnabled)
        #expect(service.registrations == 0)
        service.status = .enabled
        controller.refresh()
        #expect(controller.isEnabled)
        service.status = .notRegistered
        controller.refresh()
        #expect(!controller.isEnabled)
    }

    @Test func enablesAndDisablesOnlyWhenNecessary() {
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(service.registrations == 1)
        controller.setEnabled(false)
        controller.setEnabled(false)
        #expect(!controller.isEnabled)
        #expect(service.removals == 1)
    }

    @Test func approvalIsShownAsPendingAndCanBeCancelled() {
        let service = FakeLoginItemService()
        service.registrationStatus = .requiresApproval
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(controller.needsApproval)
        controller.setEnabled(true)
        #expect(service.registrations == 1)
        controller.setEnabled(false)
        #expect(!controller.isEnabled)
        #expect(!controller.needsApproval)
        #expect(service.removals == 1)
    }

    @Test func errorsPreserveActualSystemState() {
        let service = FakeLoginItemService()
        service.failure = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Registration refused"])
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(!controller.isEnabled)
        #expect(controller.error?.contains("Registration refused") == true)
        service.failure = nil
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(controller.error == nil)
        service.failure = NSError(domain: "test", code: 2)
        controller.setEnabled(false)
        #expect(controller.isEnabled)
        #expect(controller.error != nil)
    }
}

private final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registrationStatus: SMAppService.Status = .enabled
    var registrations = 0
    var removals = 0
    var failure: Error?
    func register() throws {
        registrations += 1
        if let failure { throw failure }
        status = registrationStatus
    }
    func unregister() throws {
        removals += 1
        if let failure { throw failure }
        status = .notRegistered
    }
}
