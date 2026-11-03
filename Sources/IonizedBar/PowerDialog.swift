import Carbon
import Foundation

enum PowerAction {
    case restart
    case shutDown

    fileprivate var eventID: AEEventID {
        switch self {
        case .restart: AEEventID(kAEShowRestartDialog)
        case .shutDown: AEEventID(kAEShowShutdownDialog)
        }
    }
}

/// Asks `loginwindow` for the macOS confirmation dialog, so a stray click can't lose work. The dialog does the rest.
func showPowerDialog(_ action: PowerAction) {
    Task.detached {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass), eventID: action.eventID,
            targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.loginwindow"),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )
        do {
            _ = try event.sendEvent(options: .waitForReply, timeout: 10)
        } catch {
            log("Could not show the \(action) dialog: \(error)")
        }
    }
}
