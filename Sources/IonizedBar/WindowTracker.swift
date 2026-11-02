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
    private var retrying: Set<pid_t> = []
    private var retryTimer: Timer?
    private var hasLoggedApiDisabled = false

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
            dirty.formUnion(Set(apps.keys).subtracting(retrying))
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
        for pid in pids {
            guard let app = apps[pid] else { continue }
            if let windows = readWindows(pid: pid, app: app) {
                apps[pid]?.windows = windows
                retrying.remove(pid)
            } else {
                retrying.insert(pid)
            }
        }
        if !retrying.isEmpty && retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [self] _ in retryReads() }
        }
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

    /// Nil when the read failed, stopping at the first failure so a hung app stalls this thread once.
    private func readWindows(pid: pid_t, app: App) -> [(element: AXUIElement, window: TrackedWindow)]? {
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

        var windows: [(element: AXUIElement, window: TrackedWindow)] = []
        for element in elements {
            var values: CFArray?
            let error = AXUIElementCopyMultipleAttributeValues(element, Self.windowAttributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
            guard error == .success else {
                if isAbsent(error) { continue }
                return nil
            }
            guard let attributes = values as? [Any], attributes.count == 4 else { continue }
            // Each attribute's own error comes back as an AXValue in the array.
            let hasFailedAttribute = attributes.contains { value in
                axValue(value, .axError, AXError.success).map { !isAbsent($0) } ?? false
            }
            guard !hasFailedAttribute else { return nil }
            guard let position = axValue(attributes[1], .cgPoint, CGPoint.zero),
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
