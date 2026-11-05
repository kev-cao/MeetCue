import Foundation
import ServiceManagement
import Testing
@testable import MeetCue

@MainActor
final class FakeLoginItem: LoginItemService {
    struct Failure: Error {}

    var status: SMAppService.Status = .notRegistered
    var statusAfterRegister: SMAppService.Status = .enabled
    var fails = false
    private(set) var openedSystemSettings = false

    func register() throws {
        if fails { throw Failure() }
        status = statusAfterRegister
    }

    func unregister() throws {
        if fails { throw Failure() }
        status = .notRegistered
    }

    func openSystemSettings() { openedSystemSettings = true }
}

@MainActor
struct LaunchAtLoginTests {
    let service = FakeLoginItem()

    @Test func reflectsTheSystemsStatus() {
        service.status = .enabled
        let login = LaunchAtLogin(service: service)
        #expect(login.isOn)
        service.status = .notFound
        #expect(login.isOn)
        login.refresh()
        #expect(!login.isOn)
        #expect(!login.needsApproval)
    }

    @Test func theSwitchRegistersAndUnregisters() {
        let login = LaunchAtLogin(service: service)
        #expect(!login.isOn)
        login.setOn(true)
        #expect(login.status == .enabled)
        #expect(login.isOn)
        login.setOn(false)
        #expect(login.status == .notRegistered)
        #expect(!login.isOn)
    }

    @Test func waitingForApprovalCountsAsOnAndLinksToSystemSettings() {
        service.statusAfterRegister = .requiresApproval
        let login = LaunchAtLogin(service: service)
        login.setOn(true)
        #expect(login.isOn)
        #expect(login.needsApproval)
        login.openSystemSettings()
        #expect(service.openedSystemSettings)
    }

    @Test func aFailedChangeSaysSoUntilOneWorks() {
        service.fails = true
        let login = LaunchAtLogin(service: service)
        login.setOn(true)
        #expect(!login.isOn)
        #expect(login.error == "Couldn't turn on launch at login.")
        service.fails = false
        login.setOn(true)
        #expect(login.isOn)
        #expect(login.error == nil)
    }
}
