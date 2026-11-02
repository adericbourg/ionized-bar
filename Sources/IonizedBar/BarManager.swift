import AppKit
import IonizedBarCore

@MainActor
final class BarManager {
    private var panels: [UInt32: BarPanel] = [:]

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
                let panel = BarPanel(frame: frame)
                panels[id] = panel
                panel.orderFrontRegardless()
            }
        }
    }
}
