import AppKit
import IonizedBarCore

/// NSScreen belongs to the main actor, so snapshots from the tracker thread land here.
@MainActor
enum WindowModel {
    static func update(_ windows: [TrackedWindow], barManager: BarManager, pusher: WindowPusher) {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return }
        let displays = screens.compactMap { screen -> Display? in
            guard let id = screen.displayID else { return nil }
            return Display(id: id, frame: screen.frame)
        }
        var byDisplay: [UInt32: [TrackedWindow]] = [:]
        var candidates: [(window: TrackedWindow, target: CGRect?)] = []
        for window in windows {
            let frame = flipRect(window.frame, primaryScreenHeight: primary.frame.height)
            var target: CGRect?
            if let display = assignDisplay(windowFrame: frame, displays: displays) {
                byDisplay[display.id, default: []].append(window)
                // A window straddling two displays is only checked against its assigned display's bar.
                if let visibleFrame = screens.first(where: { $0.displayID == display.id })?.visibleFrame {
                    target = pushTarget(frame, isMinimized: window.isMinimized, isFullScreen: window.isFullScreen, screenFrame: display.frame, visibleFrame: visibleFrame)
                        .map { flipRect($0, primaryScreenHeight: primary.frame.height) }
                }
            }
            candidates.append((window, target))
        }
        barManager.update(windowsByDisplay: byDisplay)
        pusher.update(candidates)
    }
}

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
