import AppKit
import IonizedBarCore

/// Virtual desktops. macOS has no public API to create Spaces or move windows between them, so the windows of the
/// other desktops are parked in a bottom corner of their display, behind the bar, as AeroSpace does.
@MainActor
final class Desktops {
    private let tracker: WindowTracker
    private var desktops: VirtualDesktops<AXUIElement>
    /// Parked windows, and the origin to give back, in AX coordinates.
    private var parked: [AXUIElement: (window: TrackedWindow, origin: CGPoint)] = [:]
    private var latestWindows: [TrackedWindow] = []
    /// The bars show the current desktop.
    var onSwitch: (() -> Void)?

    init(tracker: WindowTracker, count: Int) {
        self.tracker = tracker
        desktops = VirtualDesktops(count: count)
    }

    var count: Int { desktops.count }
    var current: Int { desktops.current }

    /// `screens` in AX coordinates. Returns the windows of the current desktop, and parks or brings back windows to match.
    func reconcile(_ windows: [TrackedWindow], aliveWindows: Set<AXUIElement>, screens: [CGRect]) -> [TrackedWindow] {
        latestWindows = windows
        let new = desktops.update(seen: windows.map(\.element), alive: aliveWindows)
        let seen = Set(windows.map(\.element))
        parked = parked.filter { seen.contains($0.key) || aliveWindows.contains($0.key) }
        if let focused = windows.first(where: \.isFocused), desktops.focus(focused.element) { didSwitch() }
        var shown: [TrackedWindow] = []
        for window in windows {
            let maybeScreen = screen(of: window.frame, among: screens)
            switch placement(
                isOnCurrent: desktops.isOnCurrent(window.element), isParked: parked[window.element] != nil,
                canPark: !window.isMinimized && !window.isFullScreen && maybeScreen != nil
            ) {
            case .bringBack:
                // Still at its parked frame in this snapshot: the bars and the pusher see it once it is back.
                tracker.move(window, to: parked.removeValue(forKey: window.element)!.origin)
            case .park:
                parked[window.element] = (window, window.frame.origin)
                tracker.move(window, to: parkingOrigin(size: window.frame.size, screen: maybeScreen!, otherScreens: screens.filter { $0 != maybeScreen }))
            case .stayHidden:
                break
            case .show:
                if new.contains(window.element), !window.isMinimized, isParked(window.frame, screens: screens), let screen = maybeScreen {
                    log("bringing back \(window.appName) pid=\(window.pid), left parked")
                    tracker.move(window, to: recoveredOrigin(size: window.frame.size, screen: screen))
                } else {
                    shown.append(window)
                }
            }
        }
        return shown
    }

    func switchTo(_ desktop: Int) {
        guard desktop != current else { return }
        desktops.switchTo(desktop)
        guard current == desktop else { return }
        if let key = desktops.windowToRaise(on: desktop), let window = latestWindows.first(where: { $0.element == key }), !window.isMinimized {
            tracker.raise(window)
        }
        didSwitch()
    }

    /// Parking is done on the next snapshot, which a desktop holding only minimized windows wouldn't trigger.
    private func didSwitch() {
        tracker.markAllDirty()
        onSwitch?()
    }

    func move(_ window: TrackedWindow, to desktop: Int) {
        desktops.move(window.element, to: desktop)
        tracker.markAllDirty()
    }

    func moveFocused(to desktop: Int) {
        guard let window = latestWindows.first(where: \.isFocused) else { return }
        move(window, to: desktop)
    }

    func setCount(_ newCount: Int) {
        desktops.setCount(newCount)
        tracker.markAllDirty()
    }

    /// Before quitting: the windows would stay in the corner.
    func unparkAll() {
        tracker.moveNow(parked.values.map { ($0.window, $0.origin) })
        parked = [:]
    }

    private func screen(of frame: CGRect, among screens: [CGRect]) -> CGRect? {
        assignDisplay(windowFrame: frame, displays: screens.enumerated().map { Display(id: UInt32($0.offset), frame: $0.element) })?.frame
    }
}
