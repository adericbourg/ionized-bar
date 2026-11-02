import AppKit
import IonizedBarCore

@MainActor
final class BarManager {
    private let actions: EntryActions
    private var panels: [UInt32: BarPanel] = [:]

    init(windowTracker: WindowTracker) {
        actions = EntryActions(raise: windowTracker.raise, minimize: windowTracker.minimize, restore: windowTracker.restore, close: windowTracker.close)
    }

    func sync() {
        var current: [UInt32: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let id = screen.displayID { current[id] = screen }
        }
        for id in panels.keys where current[id] == nil {
            panels.removeValue(forKey: id)?.close()
        }
        for (id, screen) in current {
            let frame = barFrame(screenFrame: screen.frame)
            if let panel = panels[id] {
                panel.setFrame(frame, display: true)
            } else {
                let panel = BarPanel(frame: frame, actions: actions)
                panels[id] = panel
                panel.orderFrontRegardless()
            }
        }
    }

    func update(windowsByDisplay: [UInt32: [TrackedWindow]]) {
        for (id, panel) in panels {
            panel.update(with: windowsByDisplay[id] ?? [])
        }
    }
}
