import AppKit
@preconcurrency import ApplicationServices
import IonizedBarCore

struct TrackedWindow: Sendable {
    let element: AXUIElement
    /// Assigned at first read and kept: AX lists windows front to back, which changes with focus.
    let order: Int
    let pid: pid_t
    let appName: String
    let title: String
    /// AX coordinates: origin at the primary display's top-left.
    let frame: CGRect
    let isMinimized: Bool
    let isFullScreen: Bool
    var isFocused: Bool
}

/// Confined to its own thread: every entry point hops there, and the observer callbacks run there.
final class WindowTracker: @unchecked Sendable {
    private struct App {
        let name: String
        let element: AXUIElement
        let observer: AXObserver
        var retry: Timer?
        /// `isFocused` here only means focused within the app; `publish()` applies the frontmost pid.
        var windows: [CachedWindow] = []
        /// Outlives the cache: a read can miss a window that is still there, or AX can omit it on another Space.
        var orders: [AXUIElement: Int] = [:]
    }

    private struct CachedWindow {
        let window: TrackedWindow
        /// Tested at publish, not at read: it depends on the hidden state, and hiding fires no read.
        let subrole: String?
    }

    private static let appNotifications = [
        kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXWindowMovedNotification,
        kAXWindowResizedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
        kAXTitleChangedNotification, kAXUIElementDestroyedNotification, kAXApplicationShownNotification
    ]
    private static let fullScreenAttribute = "AXFullScreen"
    private static let windowAttributes = [kAXTitleAttribute, kAXPositionAttribute, kAXSizeAttribute, kAXMinimizedAttribute, kAXSubroleAttribute, fullScreenAttribute]
    private static let fastAttachRetries = 10

    /// The windows to show, then every window not known to be destroyed, including those filtered out of the first.
    private let onChange: @Sendable ([TrackedWindow], sending Set<AXUIElement>) -> Void
    private var runLoop: CFRunLoop!
    private var apps: [pid_t: App] = [:]
    private var nextOrder = 0
    private var dirty: Set<pid_t> = []
    /// Moved or resized since the last refresh: the AX frame and the CG bounds may disagree for now.
    private var moving: Set<AXUIElement> = []
    private var frontmost: pid_t?
    private var debounce: Timer?
    private var refreshDeadline: Date?
    private var retrying: Set<pid_t> = []
    private var retryTimer: Timer?
    private var trailingPublish: Timer?
    private var hasLoggedApiDisabled = false

    init(onChange: @escaping @Sendable ([TrackedWindow], sending Set<AXUIElement>) -> Void) {
        self.onChange = onChange
        let ready = DispatchSemaphore(value: 0)
        Thread { [self] in
            // Applies to every AX element of the process, and bounds how long one app can stall the others.
            AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
            runLoop = CFRunLoopGetCurrent()
            // A run loop without sources exits immediately.
            RunLoop.current.add(Port(), forMode: .default)
            ready.signal()
            CFRunLoopRun()
        }.start()
        ready.wait()
    }

    func addApp(pid: pid_t) {
        onThread { [self] in
            var maybeObserver: AXObserver?
            let error = AXObserverCreate(pid, { _, element, notification, refcon in
                Unmanaged<WindowTracker>.fromOpaque(refcon!).takeUnretainedValue().handle(notification, on: element)
            }, &maybeObserver)
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
            guard let observer = maybeObserver else {
                log("no AX observer for \(name) pid=\(pid): \(error.rawValue)")
                return
            }
            CFRunLoopAddSource(runLoop, AXObserverGetRunLoopSource(observer), .defaultMode)
            apps[pid] = App(name: name, element: AXUIElementCreateApplication(pid), observer: observer)
            attach(pid, fastRetriesLeft: Self.fastAttachRetries)
        }
    }

    func removeApp(pid: pid_t) {
        onThread { [self] in
            guard apps[pid] != nil else { return }
            drop(pid)
            publish()
        }
    }

    func markAllDirty() {
        onThread { [self] in
            // An app still attaching may never answer, and gets read once its attach succeeds.
            dirty.formUnion(Set(apps.filter { $0.value.retry == nil }.keys).subtracting(retrying))
            scheduleRefresh()
        }
    }

    func setFrontmost(pid: pid_t) {
        onThread { [self] in
            frontmost = pid
            scheduleRefresh()
        }
    }

    func raise(_ window: TrackedWindow) {
        onThread { [self] in performRaise(window) }
    }

    func minimize(_ window: TrackedWindow) {
        onThread { [self] in
            set(kAXMinimizedAttribute, to: true, on: window.element, of: window)
        }
    }

    func restore(_ window: TrackedWindow) {
        onThread { [self] in
            set(kAXMinimizedAttribute, to: false, on: window.element, of: window)
            performRaise(window)
        }
    }

    func close(_ window: TrackedWindow) {
        onThread { [self] in
            var button: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(window.element, kAXCloseButtonAttribute as CFString, &button)
            guard error == .success, let button else {
                log("no close button on \(window.appName) pid=\(window.pid): AX error \(error.rawValue)")
                return
            }
            perform(kAXPressAction, on: button as! AXUIElement, of: window)
        }
    }

    /// `target` is in AX coordinates. `onStale` runs when the frame has moved on from `window.frame`, so nothing was written.
    func push(_ window: TrackedWindow, to target: CGRect, onStale: @escaping @Sendable () -> Void) {
        onThread { [self] in
            var values: CFArray?
            let attributes = [kAXPositionAttribute, kAXSizeAttribute, Self.fullScreenAttribute] as CFArray
            let error = AXUIElementCopyMultipleAttributeValues(window.element, attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
            guard error == .success, let current = values as? [Any], current.count == 3,
                  let position = axValue(current[0], .cgPoint, CGPoint.zero),
                  let size = axValue(current[1], .cgSize, CGSize.zero) else {
                log("reading the frame to push failed for \(window.appName) pid=\(window.pid): AX error \(error.rawValue)")
                return
            }
            guard current[2] as? Bool != true else { return }
            guard CGRect(origin: position, size: size) == window.frame else {
                // Its move may have posted nothing, and the cached frame would stay stale.
                moving.insert(window.element)
                markDirty(window.pid)
                onStale()
                return
            }
            // Size first: the window then fits on screen when it moves, so nothing clamps the move.
            if target.size != size {
                var value = target.size
                set(kAXSizeAttribute, to: AXValueCreate(.cgSize, &value)!, on: window.element, of: window)
            }
            if target.origin != position {
                var value = target.origin
                set(kAXPositionAttribute, to: AXValueCreate(.cgPoint, &value)!, on: window.element, of: window)
            }
            // Not every app posts moved and resized for an AX write, and the push's result comes from the next read.
            moving.insert(window.element)
            markDirty(window.pid)
        }
    }

    private func performRaise(_ window: TrackedWindow) {
        if let app = NSRunningApplication(processIdentifier: window.pid), app.isHidden, !app.unhide() {
            log("unhide failed for \(window.appName) pid=\(window.pid)")
        }
        // Not NSRunningApplication.activate: unreliable from a background app since macOS 14's cooperative activation.
        set(kAXFrontmostAttribute, to: true, on: AXUIElementCreateApplication(window.pid), of: window)
        set(kAXMainAttribute, to: true, on: window.element, of: window)
        perform(kAXRaiseAction, on: window.element, of: window)
    }

    private func set(_ attribute: String, to value: Bool, on element: AXUIElement, of window: TrackedWindow) {
        set(attribute, to: value as CFBoolean, on: element, of: window)
    }

    private func set(_ attribute: String, to value: CFTypeRef, on element: AXUIElement, of window: TrackedWindow) {
        let error = AXUIElementSetAttributeValue(element, attribute as CFString, value)
        if error != .success {
            log("setting \(attribute) failed for \(window.appName) pid=\(window.pid): AX error \(error.rawValue)")
        }
    }

    private func perform(_ action: String, on element: AXUIElement, of window: TrackedWindow) {
        let error = AXUIElementPerformAction(element, action as CFString)
        if error != .success {
            log("\(action) failed for \(window.appName) pid=\(window.pid): AX error \(error.rawValue)")
        }
    }

    private func onThread(_ block: @escaping @Sendable () -> Void) {
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    private func handle(_ notification: CFString, on element: AXUIElement) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        // On a window element this notification never fires (macOS 27.2). On the app element it
        // fires for every destroyed descendant, so keep only the windows.
        if notification as String == kAXUIElementDestroyedNotification {
            // ponytail: a window whose notification never comes keeps its entry until the app quits, one Int each; sweep with a full window list if that ever adds up.
            apps[pid]?.orders[element] = nil
            guard apps[pid]?.windows.contains(where: { CFEqual($0.window.element, element) }) == true else { return }
        }
        // Deminiaturize: the CG list lags, so the first publish could filter the restored window.
        if [kAXWindowMovedNotification, kAXWindowResizedNotification, kAXWindowDeminiaturizedNotification].contains(notification as String) {
            moving.insert(element)
        }
        markDirty(pid)
    }

    private func attach(_ pid: pid_t, fastRetriesLeft: Int) {
        guard let app = apps[pid] else { return }
        // Unretained: the tracker lives as long as the process.
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.appNotifications {
            switch AXObserverAddNotification(app.observer, app.element, name as CFString, refcon) {
            case .success, .notificationAlreadyRegistered, .notificationUnsupported:
                continue
            case .cannotComplete:
                // Keeps going until removeApp: knownPids still holds the pid, so it would never come back.
                if fastRetriesLeft == 0 { log("\(app.name) pid=\(pid) not answering; retrying attach every 5s") }
                apps[pid]?.retry = Timer.scheduledTimer(withTimeInterval: fastRetriesLeft > 0 ? 0.5 : 5, repeats: false) { [self] _ in
                    attach(pid, fastRetriesLeft: fastRetriesLeft - 1)
                }
                return
            case let error:
                log("not tracking \(app.name) pid=\(pid): AX error \(error.rawValue)")
                drop(pid)
                return
            }
        }
        apps[pid]?.retry = nil
        markDirty(pid)
    }

    private func drop(_ pid: pid_t) {
        guard let app = apps.removeValue(forKey: pid) else { return }
        app.retry?.invalidate()
        CFRunLoopRemoveSource(runLoop, AXObserverGetRunLoopSource(app.observer), .defaultMode)
        dirty.remove(pid)
        retrying.remove(pid)
    }

    private func markDirty(_ pid: pid_t) {
        // The retry timer re-reads it within 1s: its notifications must not restart the debounce.
        guard !retrying.contains(pid) else { return }
        dirty.insert(pid)
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        // The deadline stops an app retitling faster than the debounce from starving every app.
        let deadline = refreshDeadline ?? Date(timeIntervalSinceNow: 0.5)
        refreshDeadline = deadline
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: min(0.1, deadline.timeIntervalSinceNow), repeats: false) { [self] _ in refresh() }
    }

    private func refresh() {
        let pids = dirty
        dirty = []
        refreshDeadline = nil
        read(pids)
        publish()
        moving = []
        // Re-evaluates the Space check on what the first publish let through or filtered too early:
        // the CG list lags behind AX after a move, a Space switch or a deminiaturize.
        trailingPublish?.invalidate()
        trailingPublish = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [self] _ in publish() }
    }

    private func retryReads() {
        retryTimer = nil
        let pids = retrying
        read(pids)
        if retrying != pids { publish() }
    }

    /// A failed read keeps the cache and moves to the retry timer, so a hung app costs at most
    /// one messaging timeout per second, whatever the other apps are doing.
    private func read(_ pids: Set<pid_t>) {
        for pid in pids.sorted() {
            guard let app = apps[pid] else { continue }
            if let windows = readWindows(pid: pid, app: app) {
                apps[pid]?.windows = windows
                retrying.remove(pid)
            } else if retrying.insert(pid).inserted {
                log("read failed for \(app.name) pid=\(pid); retrying")
            }
        }
        if !retrying.isEmpty && retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [self] _ in retryReads() }
        }
    }

    private func publish() {
        let onScreen = onScreenWindows()
        onChange(apps.keys.flatMap { pid in
            let isAppHidden = NSRunningApplication(processIdentifier: pid)?.isHidden ?? false
            return apps[pid]!.windows.compactMap { cached -> TrackedWindow? in
                var window = cached.window
                guard isRealWindow(subrole: cached.subrole, isMinimized: window.isMinimized, isAppHidden: isAppHidden) else { return nil }
                // A failed read leaves a stale frame. Measured on TextEdit: the first read after a minimize fails.
                guard retrying.contains(pid) || moving.contains(window.element) || isOnCurrentSpace(pid: pid, frame: window.frame, isMinimized: window.isMinimized, isAppHidden: isAppHidden, onScreen: onScreen) else { return nil }
                window.isFocused = window.isFocused && pid == frontmost
                return window
            }
        }.sorted { $0.order < $1.order }, Set(apps.values.flatMap(\.orders.keys)))
    }

    /// Reads only the owner and the bounds: nothing here needs Screen Recording.
    private func onScreenWindows() -> [OnScreenWindow] {
        let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] ?? []
        return infos.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID] as? Int32,
                  let boundsValue = info[kCGWindowBounds],
                  let bounds = CGRect(dictionaryRepresentation: boundsValue as! CFDictionary) else { return nil }
            return OnScreenWindow(pid: pid, bounds: bounds)
        }
    }

    /// Nil when the read failed, stopping at the first failure so a hung app stalls this thread once.
    private func readWindows(pid: pid_t, app: App) -> [CachedWindow]? {
        var windowsValue: CFTypeRef?
        let windowsError = AXUIElementCopyAttributeValue(app.element, kAXWindowsAttribute as CFString, &windowsValue)
        guard windowsError == .success else {
            if windowsError == .apiDisabled && !hasLoggedApiDisabled {
                hasLoggedApiDisabled = true
                log("Accessibility permission lost; window list frozen")
            }
            return isAbsent(windowsError) ? [] : nil
        }
        let elements = windowsValue as? [AXUIElement] ?? []
        guard !elements.isEmpty else { return [] }

        var focusedValue: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(app.element, kAXFocusedWindowAttribute as CFString, &focusedValue)
        guard focusedError == .success || isAbsent(focusedError) else { return nil }

        var windows: [CachedWindow] = []
        for element in elements {
            var values: CFArray?
            let error = AXUIElementCopyMultipleAttributeValues(element, Self.windowAttributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
            guard error == .success else {
                if isAbsent(error) { continue }
                return nil
            }
            guard let attributes = values as? [Any], attributes.count == 6 else { continue }
            // Each attribute's own error comes back as an AXValue in the array.
            // Not for AXFullScreen: an app failing on that alone must not freeze its windows in the bar.
            let hasFailedAttribute = attributes.prefix(5).contains { value in
                axValue(value, .axError, AXError.success).map { !isAbsent($0) } ?? false
            }
            guard !hasFailedAttribute else { return nil }
            guard let position = axValue(attributes[1], .cgPoint, CGPoint.zero),
                  let size = axValue(attributes[2], .cgSize, CGSize.zero) else { continue }
            let order: Int
            if let known = apps[pid]?.orders[element] {
                order = known
            } else {
                order = nextOrder
                nextOrder += 1
                apps[pid]?.orders[element] = order
            }
            windows.append(CachedWindow(window: TrackedWindow(
                element: element,
                order: order,
                pid: pid,
                appName: app.name,
                title: attributes[0] as? String ?? "",
                frame: CGRect(origin: position, size: size),
                isMinimized: attributes[3] as? Bool ?? false,
                isFullScreen: attributes[5] as? Bool ?? false,
                isFocused: focusedValue.map { CFEqual($0, element) } ?? false
            ), subrole: attributes[4] as? String))
        }
        return windows
    }

    /// The thing being read is not there, as opposed to the read having failed.
    private func isAbsent(_ error: AXError) -> Bool {
        [.noValue, .attributeUnsupported, .invalidUIElement].contains(error)
    }

    private func axValue<T: BitwiseCopyable>(_ value: Any, _ type: AXValueType, _ initial: T) -> T? {
        let object = value as CFTypeRef
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        var result = initial
        return AXValueGetValue(object as! AXValue, type, &result) ? result : nil
    }
}
