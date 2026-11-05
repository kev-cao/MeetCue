import Foundation
import Observation
import ServiceManagement

/// Opens the app at login. `SMAppService` in the app; tests use a fake, so nothing is registered.
@MainActor
protocol LoginItemService: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

@MainActor
final class MainAppLoginItem: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// The Launch at login switch. The system keeps the state, and the user can also change it in
/// System Settings › General › Login Items, so `refresh()` reads it again each time Settings opens.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var status: SMAppService.Status
    /// Why the last change failed, shown under the switch.
    private(set) var error: String?
    @ObservationIgnored private let service: LoginItemService

    init(service: LoginItemService = MainAppLoginItem()) {
        self.service = service
        status = service.status
    }

    /// Registered, including while waiting for the user's approval in System Settings.
    var isOn: Bool { status == .enabled || status == .requiresApproval }

    var needsApproval: Bool { status == .requiresApproval }

    func refresh() {
        let current = service.status
        if current != status { error = nil }
        status = current
    }

    func setOn(_ on: Bool) {
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
            error = nil
        } catch {
            let action = on ? "turn on" : "turn off"
            self.error = "Couldn't \(action) launch at login. \(error.localizedDescription)"
        }
        status = service.status
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }
}
