import AppKit
@preconcurrency import ApplicationServices

struct TrackedWindow: Sendable {
    let pid: pid_t
    let appName: String
    let title: String
    /// AX coordinates: origin at the primary display's top-left.
    let frame: CGRect
    let isMinimized: Bool
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
        var windows: [(element: AXUIElement, window: TrackedWindow)] = []
    }

    private static let appNotifications = [
        kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXWindowMovedNotification,
        kAXWindowResizedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
        kAXTitleChangedNotification, kAXUIElementDestroyedNotification
    ]
    private static let windowAttributes = [kAXTitleAttribute, kAXPositionAttribute, kAXSizeAttribute, kAXMinimizedAttribute]
    private static let maxAttachRetries = 10

    private let onChange: @Sendable ([TrackedWindow]) -> Void
    private var runLoop: CFRunLoop!
    private var apps: [pid_t: App] = [:]
    private var dirty: Set<pid_t> = []
    private var frontmost: pid_t?
    private var debounce: Timer?
    private var refreshDeadline: Date?

    init(onChange: @escaping @Sendable ([TrackedWindow]) -> Void) {
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
            attach(pid, retriesLeft: Self.maxAttachRetries)
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
            dirty.formUnion(apps.keys)
            scheduleRefresh()
        }
    }

    func setFrontmost(pid: pid_t) {
        onThread { [self] in
            frontmost = pid
            scheduleRefresh()
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
        if notification as String == kAXUIElementDestroyedNotification,
           apps[pid]?.windows.contains(where: { CFEqual($0.element, element) }) != true {
            return
        }
        markDirty(pid)
    }

    private func attach(_ pid: pid_t, retriesLeft: Int) {
        guard let app = apps[pid] else { return }
        // Unretained: the tracker lives as long as the process.
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.appNotifications {
            switch AXObserverAddNotification(app.observer, app.element, name as CFString, refcon) {
            case .success, .notificationAlreadyRegistered, .notificationUnsupported:
                continue
            case .cannotComplete where retriesLeft > 0:
                apps[pid]?.retry = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [self] _ in
                    attach(pid, retriesLeft: retriesLeft - 1)
                }
                return
            case let error:
                log("not tracking \(app.name) pid=\(pid): AX error \(error.rawValue)")
                drop(pid)
                return
            }
        }
        markDirty(pid)
    }

    private func drop(_ pid: pid_t) {
        guard let app = apps.removeValue(forKey: pid) else { return }
        app.retry?.invalidate()
        CFRunLoopRemoveSource(runLoop, AXObserverGetRunLoopSource(app.observer), .defaultMode)
        dirty.remove(pid)
    }

    private func markDirty(_ pid: pid_t) {
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
        for pid in dirty {
            if let app = apps[pid], let windows = readWindows(pid: pid, app: app) {
                apps[pid]?.windows = windows
            }
        }
        dirty = []
        refreshDeadline = nil
        publish()
    }

    private func publish() {
        onChange(apps.keys.sorted().flatMap { pid in
            apps[pid]!.windows.map { _, window in
                var window = window
                window.isFocused = window.isFocused && pid == frontmost
                return window
            }
        })
    }

    /// Nil when the app timed out: the caller keeps its cache, and stopping at the first timeout
    /// keeps a hung app's stall to one messaging timeout per refresh.
    // ponytail: the app stays stale until its next notification; retry here if that shows up in practice.
    private func readWindows(pid: pid_t, app: App) -> [(element: AXUIElement, window: TrackedWindow)]? {
        var windowsValue: CFTypeRef?
        switch AXUIElementCopyAttributeValue(app.element, kAXWindowsAttribute as CFString, &windowsValue) {
        case .success: break
        case .cannotComplete: return nil
        default: return []
        }
        let elements = windowsValue as? [AXUIElement] ?? []
        guard !elements.isEmpty else { return [] }

        var focusedValue: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(app.element, kAXFocusedWindowAttribute as CFString, &focusedValue)
        guard focusedError != .cannotComplete else { return nil }

        var windows: [(element: AXUIElement, window: TrackedWindow)] = []
        for element in elements {
            var values: CFArray?
            let error = AXUIElementCopyMultipleAttributeValues(element, Self.windowAttributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
            guard error != .cannotComplete else { return nil }
            guard error == .success, let attributes = values as? [Any], attributes.count == 4,
                  let position = axValue(attributes[1], .cgPoint, CGPoint.zero),
                  let size = axValue(attributes[2], .cgSize, CGSize.zero) else { continue }
            windows.append((element, TrackedWindow(
                pid: pid,
                appName: app.name,
                title: attributes[0] as? String ?? "",
                frame: CGRect(origin: position, size: size),
                isMinimized: attributes[3] as? Bool ?? false,
                isFocused: focusedValue.map { CFEqual($0, element) } ?? false
            )))
        }
        return windows
    }

    private func axValue<T: BitwiseCopyable>(_ value: Any, _ type: AXValueType, _ initial: T) -> T? {
        let object = value as CFTypeRef
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        var result = initial
        return AXValueGetValue(object as! AXValue, type, &result) ? result : nil
    }
}
