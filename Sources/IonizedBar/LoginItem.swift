import Foundation
import ServiceManagement

enum LoginItem {
    private static let registeredOnceKey = "loginItemRegisteredOnce"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ isOn: Bool) {
        do {
            if isOn { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log("Login item \(isOn ? "register" : "unregister") failed: \(error)")
        }
    }

    // On by default, but only once: a user who later turns it off is not overridden.
    static func registerOnce() {
        guard !UserDefaults.standard.bool(forKey: registeredOnceKey) else { return }
        UserDefaults.standard.set(true, forKey: registeredOnceKey)
        set(true)
    }
}
