import AppKit
import Carbon.HIToolbox
import IonizedBarCore

/// Display-only: it never becomes key or activates the app, and clicks on it do nothing.
final class PreviewPanel: NSPanel {
    private static let width: CGFloat = 320
    private static let padding: CGFloat = 10
    private static let iconSize: CGFloat = 32
    private static let maxThumbnailHeight: CGFloat = 200
    static let cornerRadius: CGFloat = 10
    private static let gap: CGFloat = 4

    private let icon = NSImageView()
    private let appName = NSTextField(labelWithString: "")
    private let windowTitle = NSTextField(labelWithString: "")
    private let thumbnail = NSImageView()
    private let onPointerExit: () -> Void

    init(onPointerExit: @escaping () -> Void) {
        self.onPointerExit = onPointerExit
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        let frosted = setUpFloating()
        frosted.maskImage = Self.roundedMask
        appName.font = .boldSystemFont(ofSize: 13)
        windowTitle.font = .systemFont(ofSize: 12)
        windowTitle.textColor = .secondaryLabelColor
        for label in [appName, windowTitle] { label.lineBreakMode = .byTruncatingTail }
        icon.setAccessibilityElement(false)
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        for view in [icon, appName, windowTitle, thumbnail] { frosted.addSubview(view) }
        // activeAlways: this app is never the active one, and inVisibleRect follows the panel's resizes.
        frosted.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    static var roundedMask: NSImage {
        let side = cornerRadius * 2 + 1
        let mask = NSImage(size: CGSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        mask.resizingMode = .stretch
        return mask
    }

    override func mouseExited(with event: NSEvent) { onPointerExit() }

    /// A nil `image` shows the header only.
    func show(_ window: TrackedWindow, image: CGImage?, above entry: CGRect, on screen: CGRect) {
        icon.image = NSRunningApplication(processIdentifier: window.pid)?.icon
        appName.stringValue = window.appName
        windowTitle.stringValue = window.title
        windowTitle.isHidden = window.title.isEmpty
        thumbnail.image = image.map { NSImage(cgImage: $0, size: .zero) }
        thumbnail.isHidden = image == nil
        thumbnail.setAccessibilityLabel("Preview of \(window.title.isEmpty ? window.appName : window.title)")

        let innerWidth = Self.width - 2 * Self.padding
        let thumbnailSize = image.map {
            fittedSize(CGSize(width: $0.width, height: $0.height), within: CGSize(width: innerWidth, height: Self.maxThumbnailHeight))
        } ?? .zero
        let thumbnailBlock = image == nil ? 0 : thumbnailSize.height + Self.padding
        let height = 2 * Self.padding + Self.iconSize + thumbnailBlock
        setFrame(previewFrame(entry: entry, size: CGSize(width: Self.width, height: height), screen: screen, gap: Self.gap), display: true)

        let headerY = height - Self.padding - Self.iconSize
        icon.frame = CGRect(x: Self.padding, y: headerY, width: Self.iconSize, height: Self.iconSize)
        let textX = icon.frame.maxX + 8
        let textWidth = Self.width - textX - Self.padding
        let nameHeight = appName.intrinsicContentSize.height
        let titleHeight = windowTitle.intrinsicContentSize.height
        let textTop = headerY + ((Self.iconSize + nameHeight + (window.title.isEmpty ? 0 : titleHeight)) / 2).rounded()
        appName.frame = CGRect(x: textX, y: textTop - nameHeight, width: textWidth, height: nameHeight)
        windowTitle.frame = CGRect(x: textX, y: textTop - nameHeight - titleHeight, width: textWidth, height: titleHeight)
        thumbnail.frame = CGRect(x: ((Self.width - thumbnailSize.width) / 2).rounded(), y: Self.padding, width: thumbnailSize.width, height: thumbnailSize.height)
        invalidateShadow()
        orderFrontRegardless()
    }
}

/// One panel for the whole app, on one entry at a time.
@MainActor
final class PreviewController {
    private static let hoverDelay: Duration = .milliseconds(300)
    // Long enough for the pointer to cross the gap between the entry and the panel.
    private static let hideGrace: Duration = .milliseconds(150)

    private let thumbnail: @MainActor (TrackedWindow) async -> CGImage?
    // Lazy: with previews off, no panel exists.
    private lazy var panel = PreviewPanel { [unowned self] in pointerLeft() }
    private var entry: EntryView?
    /// No preview starts during a drag. Weak: a bar closed mid-drag gets no mouse-up, and mustn't leave previews off.
    weak var dragged: NSView? {
        didSet { dismiss() }
    }
    private var showing: Task<Void, Never>?
    private var hiding: Task<Void, Never>?
    private var escapeMonitors: [Any] = []

    /// `thumbnail` is called once per preview, on the main actor.
    init(thumbnail: @escaping @MainActor (TrackedWindow) async -> CGImage?) {
        self.thumbnail = thumbnail
    }

    func show(for entry: EntryView) {
        guard dragged == nil, entry !== self.entry else { return }
        dismiss()
        guard entry.previewWindow != nil else { return }
        self.entry = entry
        showing = Task { [weak self] in
            try? await Task.sleep(for: Self.hoverDelay)
            guard !Task.isCancelled else { return }
            await self?.present(entry)
        }
    }

    private func present(_ entry: EntryView) async {
        // Read now: the window may have changed during the delay.
        guard let window = entry.previewWindow, let entryWindow = entry.window, let screen = entryWindow.screen else { return dismiss() }
        let frame = entryWindow.convertToScreen(entry.convert(entry.bounds, to: nil))
        panel.show(window, image: nil, above: frame, on: screen.frame)
        addEscapeMonitors()
        guard let image = await thumbnail(window), !Task.isCancelled else { return }
        panel.show(window, image: image, above: frame, on: screen.frame)
    }

    func pointerLeft(_ entry: EntryView) {
        guard entry === self.entry else { return }
        if panel.isVisible { pointerLeft() } else { dismiss() }
    }

    private func pointerLeft() {
        // A late exit from a panel already dismissed: its grace would cancel the next preview.
        guard entry != nil else { return }
        hiding?.cancel()
        hiding = Task { [weak self] in
            try? await Task.sleep(for: Self.hideGrace)
            guard !Task.isCancelled else { return }
            self?.dismissUnlessPointerIsOver()
        }
    }

    // Checked after the grace rather than cancelled on enter: the exit and enter of two windows come in no set order.
    private func dismissUnlessPointerIsOver() {
        guard let entry, let entryWindow = entry.window else { return dismiss() }
        let mouse = NSEvent.mouseLocation
        let entryFrame = entryWindow.convertToScreen(entry.convert(entry.bounds, to: nil))
        if panel.frame.contains(mouse) || entryFrame.contains(mouse) { return }
        // No tracking area covers the gap, so nothing would report the pointer leaving it: check again.
        if isInPreviewGap(mouse, entry: entryFrame, panel: panel.frame) { pointerLeft() } else { dismiss() }
    }

    func dismiss(for entry: EntryView) {
        if entry === self.entry { dismiss() }
    }

    func dismiss() {
        guard entry != nil else { return }
        entry = nil
        // Cancelling is what keeps a late capture off the panel once it is on another entry.
        showing?.cancel()
        hiding?.cancel()
        panel.orderOut(nil)
        escapeMonitors.forEach(NSEvent.removeMonitor)
        escapeMonitors = []
    }

    // Only while a panel shows. The global monitor gets the keys sent to other apps (documented to need only
    // Accessibility, which the app holds) and observes the key without taking it, so the frontmost app gets Esc too.
    // It only ever reads the key code. The local one gets those sent to this app: keyboard mode and the settings window.
    private func addEscapeMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == kVK_Escape { self?.dismiss() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == kVK_Escape else { return event }
            self?.dismiss()
            return nil
        }
        escapeMonitors = [global, local].compactMap { $0 }
    }
}
