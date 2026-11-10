import Foundation
import ServiceManagement

enum LoginItem {
    private static let registeredOnceKey = "loginItemRegisteredOnce"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ isOn: Bool) {
        do {
            if isOn { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            // Any success settles it, a choice made in Settings included: the automatic registration must not override it later.
            UserDefaults.standard.set(true, forKey: registeredOnceKey)
        } catch {
            log("Login item \(isOn ? "register" : "unregister") failed: \(error)")
        }
    }

    // On by default, but only once: a user who later turns it off is not overridden. A failed attempt doesn't count, and the next launch tries again.
    static func registerOnce() {
        guard !UserDefaults.standard.bool(forKey: registeredOnceKey) else { return }
        set(true)
    }
}
