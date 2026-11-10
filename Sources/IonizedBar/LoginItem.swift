import Foundation
import ServiceManagement

enum LoginItem {
    private static let registeredOnceKey = "loginItemRegisteredOnce"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// False when it failed.
    @discardableResult
    static func set(_ isOn: Bool) -> Bool {
        do {
            if isOn { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            log("Login item \(isOn ? "register" : "unregister") failed: \(error)")
            return false
        }
    }

    // On by default, but only once: a user who later turns it off is not overridden. A failed attempt doesn't count, and the next launch tries again.
    static func registerOnce() {
        guard !UserDefaults.standard.bool(forKey: registeredOnceKey), set(true) else { return }
        UserDefaults.standard.set(true, forKey: registeredOnceKey)
    }
}
