import AppKit
import IonizedBarCore

/// NSScreen belongs to the main actor, so snapshots from the tracker thread land here.
@MainActor
enum WindowModel {
    static func update(_ windows: [TrackedWindow], barManager: BarManager) {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return }
        let displays = screens.compactMap { screen -> Display? in
            guard let id = screen.displayID else { return nil }
            return Display(id: id, frame: screen.frame)
        }
        var byDisplay: [UInt32: [TrackedWindow]] = [:]
        var unassigned: [TrackedWindow] = []
        for window in windows {
            let frame = flipRect(window.frame, primaryScreenHeight: primary.frame.height)
            if let display = assignDisplay(windowFrame: frame, displays: displays) {
                byDisplay[display.id, default: []].append(window)
            } else {
                unassigned.append(window)
            }
        }
        log("snapshot: \(windows.count) windows on \(displays.count) displays")
        for display in displays {
            let assigned = byDisplay[display.id] ?? []
            log("  display \(display.id): \(assigned.count) windows")
            assigned.forEach(logWindow)
        }
        if !unassigned.isEmpty {
            log("  unassigned: \(unassigned.count) windows")
            unassigned.forEach(logWindow)
        }
        barManager.update(windowsByDisplay: byDisplay)
    }

    private static func logWindow(_ window: TrackedWindow) {
        log("    \(window.appName) \"\(window.title)\" minimized=\(window.isMinimized) focused=\(window.isFocused)")
    }
}

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
