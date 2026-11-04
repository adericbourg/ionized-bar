import AppKit
import Carbon.HIToolbox
import IonizedBarCore

/// Key without activating the app, like the launcher, so Tab reaches the arrows.
final class CalendarPanel: NSPanel {
    private static let padding: CGFloat = 14
    private static let titleHeight: CGFloat = 36
    private static let arrowSize: CGFloat = 28
    private static let headerHeight: CGFloat = 32
    private static let cellSize = CGSize(width: 44, height: 44)
    private static let weekColumnWidth: CGFloat = 44
    // Always room for the longest month, so that the arrows stay under the pointer from month to month.
    private static let maxRows: CGFloat = 6

    static func size(showsWeekNumbers: Bool) -> CGSize {
        CGSize(
            width: 2 * padding + 7 * cellSize.width + (showsWeekNumbers ? weekColumnWidth : 0),
            height: 2 * padding + titleHeight + headerHeight + maxRows * cellSize.height
        )
    }

    private let tint = makeDarkTint(cornerRadius: PreviewPanel.cornerRadius)
    private let titleLabel = NSTextField(labelWithString: "")
    private lazy var previousButton = FooterButton(title: "", symbolName: "chevron.left", target: self, action: #selector(previousClicked))
    private lazy var nextButton = FooterButton(title: "", symbolName: "chevron.right", target: self, action: #selector(nextClicked))
    private let grid = NSView()
    private var month = Date()
    private var settings = CalendarSettings()
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        appearance = NSAppearance(named: .darkAqua)
        let frosted = setUpFloating()
        frosted.maskImage = PreviewPanel.roundedMask
        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        previousButton.imagePosition = .imageOnly
        nextButton.imagePosition = .imageOnly
        previousButton.setAccessibilityLabel("Previous month")
        nextButton.setAccessibilityLabel("Next month")
        previousButton.nextKeyView = nextButton
        nextButton.nextKeyView = previousButton
        for view in [tint, titleLabel, previousButton, nextButton, grid] { frosted.addSubview(view) }
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onDismiss() }

    // Nothing is focused until Tab, so the keys end up here with no control to pass them on.
    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape { onDismiss() } else { super.keyDown(with: event) }
    }

    override func resignKey() {
        super.resignKey()
        onDismiss()
    }

    func show(in frame: CGRect, settings: CalendarSettings) {
        self.settings = settings
        month = Date()
        setFrame(frame, display: false)
        tint.frame = CGRect(origin: .zero, size: frame.size)
        let titleY = frame.height - Self.padding - Self.titleHeight
        let arrowY = titleY + ((Self.titleHeight - Self.arrowSize) / 2).rounded()
        nextButton.frame = CGRect(x: frame.width - Self.padding - Self.arrowSize, y: arrowY, width: Self.arrowSize, height: Self.arrowSize)
        previousButton.frame = CGRect(x: nextButton.frame.minX - Self.arrowSize, y: arrowY, width: Self.arrowSize, height: Self.arrowSize)
        let titleHeight = titleLabel.intrinsicContentSize.height
        titleLabel.frame = CGRect(
            x: Self.padding, y: titleY + ((Self.titleHeight - titleHeight) / 2).rounded(),
            width: previousButton.frame.minX - Self.padding, height: titleHeight
        )
        grid.frame = CGRect(x: Self.padding, y: Self.padding, width: frame.width - 2 * Self.padding, height: titleY - Self.padding)
        reload()
        invalidateShadow()
        orderFrontRegardless()
        makeKey()
        // Focus waits for Tab: with the pointer, a ring on an arrow would only be noise.
        makeFirstResponder(nil)
    }

    private func reload() {
        titleLabel.stringValue = calendarTitle(month: month)
        grid.subviews.forEach { $0.removeFromSuperview() }
        let firstWeekday = settings.firstWeekday.calendarWeekday()
        let daysX = settings.showsWeekNumbers ? Self.weekColumnWidth : 0
        let headerY = grid.bounds.height - Self.headerHeight
        for (column, text) in calendarWeekdayHeaders(firstWeekday: firstWeekday).enumerated() {
            addLabel(text, in: CGRect(x: daysX + CGFloat(column) * Self.cellSize.width, y: headerY, width: Self.cellSize.width, height: Self.headerHeight))
        }
        for (row, week) in monthGrid(month: month, today: Date(), firstWeekday: firstWeekday).enumerated() {
            let y = headerY - CGFloat(row + 1) * Self.cellSize.height
            if settings.showsWeekNumbers {
                addLabel("W\(week.number)", in: CGRect(x: 0, y: y, width: Self.weekColumnWidth, height: Self.cellSize.height))
            }
            for (column, day) in week.days.enumerated() {
                let cell = DayCell(day: day)
                cell.frame = CGRect(x: daysX + CGFloat(column) * Self.cellSize.width, y: y, width: Self.cellSize.width, height: Self.cellSize.height)
                grid.addSubview(cell)
            }
        }
    }

    private func addLabel(_ text: String, in cellFrame: CGRect) {
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        let height = label.intrinsicContentSize.height
        label.frame = CGRect(x: cellFrame.minX, y: cellFrame.minY + ((cellFrame.height - height) / 2).rounded(), width: cellFrame.width, height: height)
        grid.addSubview(label)
    }

    @objc private func previousClicked() { move(by: -1) }

    @objc private func nextClicked() { move(by: 1) }

    private func move(by offset: Int) {
        month = movedMonth(month, by: offset)
        reload()
        // On the panel: it can't become main, so the usual NSApp.mainWindow is nil here.
        NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [
            .announcement: titleLabel.stringValue,
            .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
    }
}

/// Text for VoiceOver, not a button: the hover only helps to read across rows and columns.
private final class DayCell: NSView {
    private static let inset: CGFloat = 3
    private static let ringWidth: CGFloat = 1.5

    private let day: CalendarDay
    private let label: NSTextField
    private var isHovered = false {
        didSet {
            needsDisplay = true
            updateTextColor()
        }
    }

    init(day: CalendarDay) {
        self.day = day
        label = NSTextField(labelWithString: String(day.number))
        super.init(frame: .zero)
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        label.alignment = .center
        label.setAccessibilityElement(false)
        addSubview(label)
        updateTextColor()
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(calendarDayAccessibilityLabel(day))
        // Always active: this app is never the active one while the panel is open.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // Read as one element: its label spells out the date.
    override func accessibilityChildren() -> [Any]? { [] }

    private func updateTextColor() {
        label.textColor = isHovered ? .alternateSelectedControlTextColor : day.isInMonth ? .labelColor : .secondaryLabelColor
    }

    override func layout() {
        super.layout()
        let height = label.intrinsicContentSize.height
        label.frame = CGRect(x: 0, y: ((bounds.height - height) / 2).rounded(), width: bounds.width, height: height)
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }

    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        let tile = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        if isHovered {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: tile, xRadius: 6, yRadius: 6).fill()
        }
        guard day.isToday else { return }
        // The accent doesn't show on the accent fill, so a hovered today takes the color of the text on it.
        (isHovered ? NSColor.alternateSelectedControlTextColor : NSColor.controlAccentColor).setStroke()
        let ring = NSBezierPath(roundedRect: tile.insetBy(dx: Self.ringWidth / 2, dy: Self.ringWidth / 2), xRadius: 6, yRadius: 6)
        ring.lineWidth = Self.ringWidth
        ring.stroke()
    }
}

/// One panel for the whole app, above one clock at a time.
@MainActor
final class CalendarController {
    private static let gap: CGFloat = 4

    private lazy var panel = CalendarPanel(onDismiss: { [unowned self] in close() })
    private var button: NSView?
    private var maybeClickMonitor: PanelClickMonitor?

    var isOpen: Bool { button != nil }

    func toggle(above button: NSView, settings: CalendarSettings) {
        let isOpenHere = button === self.button
        close()
        if !isOpenHere { open(above: button, settings: settings) }
    }

    private func open(above button: NSView, settings: CalendarSettings) {
        guard let window = button.window, let screen = window.screen else { return }
        self.button = button
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let size = CalendarPanel.size(showsWeekNumbers: settings.showsWeekNumbers)
        panel.show(in: launcherFrame(button: buttonFrame, size: size, screen: screen.visibleFrame, gap: Self.gap), settings: settings)
        maybeClickMonitor = PanelClickMonitor(panel: panel, button: button) { [weak self] in self?.close() }
    }

    func close() {
        guard button != nil else { return }
        button = nil
        maybeClickMonitor = nil
        // Ordering out is what hands key back to the frontmost app, as in BarPanel.endKeyboardMode.
        panel.orderOut(nil)
    }
}
