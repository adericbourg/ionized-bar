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
        var overlapping: [TrackedWindow] = []
        for window in windows {
            let frame = flipRect(window.frame, primaryScreenHeight: primary.frame.height)
            if let display = assignDisplay(windowFrame: frame, displays: displays) {
                byDisplay[display.id, default: []].append(window)
                // A window straddling two displays is only checked against its assigned display's bar.
                if !window.isMinimized, overlapsBar(frame, bar: barFrame(screenFrame: display.frame)) {
                    overlapping.append(window)
                }
            }
        }
        if !overlapping.isEmpty {
            log("overlapping the bar: " + overlapping.map { "\($0.appName) (pid \($0.pid))" }.joined(separator: ", "))
        }
        barManager.update(windowsByDisplay: byDisplay)
    }
}

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
