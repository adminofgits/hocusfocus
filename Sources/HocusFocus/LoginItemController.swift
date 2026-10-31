import Foundation
import ServiceManagement
import Combine

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var error: String?
    private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func refresh() { status = service.status }

    func setEnabled(_ enabled: Bool) {
        refresh()
        error = nil
        do {
            if enabled && !isEnabled { try service.register() }
            if !enabled && isEnabled { try service.unregister() }
        } catch {
            self.error = "Could not change launch at login: \(error.localizedDescription)"
        }
        refresh()
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
