import AppKit
import Carbon.HIToolbox
import IonizedBarCore

/// Key without activating the app, like the launcher, so Tab reaches the buttons.
final class CalendarPanel: NSPanel {
    private enum Mode { case days, months, years }

    private static let padding: CGFloat = 14
    private static let titleHeight: CGFloat = 36
    private static let arrowSize: CGFloat = 28
    private static let headerHeight: CGFloat = 32
    private static let footerHeight: CGFloat = 24
    private static let cellSize = CGSize(width: 44, height: 44)
    private static let weekColumnWidth: CGFloat = 44
    // Always room for the longest month, so that the arrows stay under the pointer from month to month.
    private static let maxRows: CGFloat = 6
    private static let titleOutset: CGFloat = 4
    private static let pickColumns: CGFloat = 3
    private static let pickRows: CGFloat = 4

    static func size(showsWeekNumbers: Bool) -> CGSize {
        CGSize(
            width: 2 * padding + 7 * cellSize.width + (showsWeekNumbers ? weekColumnWidth : 0),
            height: 2 * padding + titleHeight + headerHeight + maxRows * cellSize.height + footerHeight
        )
    }

    private let tint = makeDarkTint(cornerRadius: PreviewPanel.cornerRadius)
    private let titleLabel = NSTextField(labelWithString: "")
    private lazy var titleButton = FooterButton(title: "", symbolName: nil, target: self, action: #selector(titleClicked))
    private lazy var previousButton = FooterButton(title: "", symbolName: "chevron.left", target: self, action: #selector(previousClicked))
    private lazy var nextButton = FooterButton(title: "", symbolName: "chevron.right", target: self, action: #selector(nextClicked))
    private let grid = NSView()
    private let footerLabel = NSTextField(labelWithString: "")
    private weak var maybeHoveredCell: DayCell?
    private var mode = Mode.days
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
        titleButton.font = titleLabel.font
        previousButton.imagePosition = .imageOnly
        nextButton.imagePosition = .imageOnly
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.alignment = .center
        // VoiceOver reads the same text in each day's label.
        footerLabel.setAccessibilityElement(false)
        for view in [tint, titleLabel, titleButton, previousButton, nextButton, grid, footerLabel] { frosted.addSubview(view) }
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
        mode = .days
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
        let footerTextHeight = footerLabel.intrinsicContentSize.height
        footerLabel.frame = CGRect(
            x: Self.padding, y: Self.padding + ((Self.footerHeight - footerTextHeight) / 2).rounded(),
            width: frame.width - 2 * Self.padding, height: footerTextHeight
        )
        let gridY = Self.padding + Self.footerHeight
        grid.frame = CGRect(x: Self.padding, y: gridY, width: frame.width - 2 * Self.padding, height: titleY - gridY)
        reload()
        invalidateShadow()
        orderFrontRegardless()
        makeKey()
        // Focus waits for Tab: with the pointer, a ring on an arrow would only be noise.
        makeFirstResponder(nil)
    }

    private func reload() {
        grid.subviews.forEach { $0.removeFromSuperview() }
        footerLabel.stringValue = ""
        switch mode {
        case .days:
            reloadDays()
            updateHeader(title: calendarTitle(month: month), unit: "month", maybeTitleAction: "choose a month")
        case .months:
            reloadPicks(calendarMonthPicks(month: month, today: Date()))
            updateHeader(title: calendarYearTitle(month: month), unit: "year", maybeTitleAction: "choose a year")
        case .years:
            reloadPicks(calendarYearPicks(month: month, today: Date()))
            updateHeader(title: calendarYearPageTitle(month: month), unit: "years", maybeTitleAction: nil)
        }
        let titleViews = titleButton.isHidden ? [] : [titleButton]
        let keyViews: [NSView] = titleViews + [previousButton, nextButton] + pickCells
        for (view, next) in zip(keyViews, keyViews.dropFirst() + keyViews.prefix(1)) { view.nextKeyView = next }
    }

    private var pickCells: [PickCell] { grid.subviews.compactMap { $0 as? PickCell } }

    private func updateHeader(title: String, unit: String, maybeTitleAction: String?) {
        titleLabel.stringValue = title
        titleLabel.isHidden = maybeTitleAction != nil
        titleButton.isHidden = maybeTitleAction == nil
        if let titleAction = maybeTitleAction {
            titleButton.title = title
            titleButton.setAccessibilityLabel("\(title), \(titleAction)")
            titleButton.sizeToFit()
            // Wider than the text, with the same outset on the left, so that the text lines up with the label's.
            titleButton.frame = CGRect(
                x: Self.padding - Self.titleOutset, y: previousButton.frame.minY,
                width: min(titleButton.frame.width + 2 * Self.titleOutset, previousButton.frame.minX - Self.padding), height: Self.arrowSize
            )
        }
        previousButton.setAccessibilityLabel("Previous \(unit)")
        nextButton.setAccessibilityLabel("Next \(unit)")
    }

    private func reloadPicks(_ picks: [CalendarPick]) {
        let size = CGSize(width: grid.bounds.width / Self.pickColumns, height: grid.bounds.height / Self.pickRows)
        for (index, pick) in picks.enumerated() {
            let cell = PickCell(pick: pick, target: self, action: #selector(pickClicked))
            let column = CGFloat(index % Int(Self.pickColumns)), row = CGFloat(index / Int(Self.pickColumns))
            cell.frame = CGRect(x: column * size.width, y: grid.bounds.height - (row + 1) * size.height, width: size.width, height: size.height)
            grid.addSubview(cell)
        }
    }

    private func reloadDays() {
        let firstWeekday = settings.firstWeekday.calendarWeekday()
        let daysX = settings.showsWeekNumbers ? Self.weekColumnWidth : 0
        let today = Date()
        let headerY = grid.bounds.height - Self.headerHeight
        for (column, text) in calendarWeekdayHeaders(firstWeekday: firstWeekday).enumerated() {
            addLabel(text, in: CGRect(x: daysX + CGFloat(column) * Self.cellSize.width, y: headerY, width: Self.cellSize.width, height: Self.headerHeight))
        }
        for (row, week) in monthGrid(month: month, today: today, firstWeekday: firstWeekday).enumerated() {
            let y = headerY - CGFloat(row + 1) * Self.cellSize.height
            if settings.showsWeekNumbers {
                addLabel("W\(week.number)", in: CGRect(x: 0, y: y, width: Self.weekColumnWidth, height: Self.cellSize.height))
            }
            for (column, day) in week.days.enumerated() {
                let cell = DayCell(day: day, distance: calendarDistanceText(from: today, to: day.date, format: settings.distanceFormat))
                cell.onHover = { [unowned self] cell, isHovered in hoverChanged(cell, isHovered: isHovered) }
                cell.frame = CGRect(x: daysX + CGFloat(column) * Self.cellSize.width, y: y, width: Self.cellSize.width, height: Self.cellSize.height)
                grid.addSubview(cell)
            }
        }
    }

    // Leaving one day and entering the next can come in either order.
    private func hoverChanged(_ cell: DayCell, isHovered: Bool) {
        if isHovered {
            maybeHoveredCell = cell
            footerLabel.stringValue = cell.distance
        } else if maybeHoveredCell === cell {
            maybeHoveredCell = nil
            footerLabel.stringValue = ""
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

    private func move(by direction: Int) {
        let step = switch mode {
        case .days: 1
        case .months: 12
        case .years: 144
        }
        month = movedMonth(month, by: direction * step)
        reload()
        announceTitle()
    }

    @objc private func titleClicked() {
        switchScreen(to: mode == .days ? .months : .years, month: month)
    }

    @objc private func pickClicked(_ cell: PickCell) {
        switchScreen(to: mode == .years ? .months : .days, month: cell.pick.date)
    }

    private func switchScreen(to mode: Mode, month: Date) {
        // Only the keyboard focuses a button. It would otherwise vanish with the view that had it.
        let hadFocus = firstResponder is NSButton
        self.mode = mode
        self.month = month
        reload()
        if hadFocus { makeFirstResponder(pickCells.first { $0.pick.isCurrent } ?? previousButton) }
        announceTitle()
    }

    private func announceTitle() {
        // On the panel: it can't become main, so the usual NSApp.mainWindow is nil here.
        NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [
            .announcement: titleLabel.stringValue,
            .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
    }
}

/// The accent fill on hover, and the outline on what is current: the look of a day, today included.
private func drawCalendarTile(in bounds: CGRect, isHovered: Bool, isMarked: Bool) {
    let inset: CGFloat = 3, ringWidth: CGFloat = 1.5
    let tile = bounds.insetBy(dx: inset, dy: inset)
    if isHovered {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: tile, xRadius: 6, yRadius: 6).fill()
    }
    guard isMarked else { return }
    // The accent doesn't show on the accent fill, so a hovered one takes the color of the text on it.
    (isHovered ? NSColor.alternateSelectedControlTextColor : NSColor.controlAccentColor).setStroke()
    let ring = NSBezierPath(roundedRect: tile.insetBy(dx: ringWidth / 2, dy: ringWidth / 2), xRadius: 6, yRadius: 6)
    ring.lineWidth = ringWidth
    ring.stroke()
}

private final class PickCell: FooterButton {
    let pick: CalendarPick

    init(pick: CalendarPick, target: AnyObject, action: Selector) {
        self.pick = pick
        super.init(title: pick.text, symbolName: nil, target: target, action: action)
        font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        setAccessibilityLabel(pick.isCurrent ? "\(pick.accessibilityLabel), current" : pick.accessibilityLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        contentTintColor = .alternateSelectedControlTextColor
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        contentTintColor = .labelColor
    }

    override func drawBackground() {
        drawCalendarTile(in: bounds, isHovered: isHovered, isMarked: pick.isCurrent)
    }
}

/// Text for VoiceOver, not a button: the hover only helps to read across rows and columns.
private final class DayCell: NSView {
    private let day: CalendarDay
    let distance: String
    var onHover: ((DayCell, Bool) -> Void)?
    private let label: NSTextField
    private var isHovered = false {
        didSet {
            needsDisplay = true
            updateTextColor()
            onHover?(self, isHovered)
        }
    }

    init(day: CalendarDay, distance: String) {
        self.day = day
        self.distance = distance
        label = NSTextField(labelWithString: String(day.number))
        super.init(frame: .zero)
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        label.alignment = .center
        label.setAccessibilityElement(false)
        addSubview(label)
        updateTextColor()
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        let date = calendarDayAccessibilityLabel(day)
        setAccessibilityLabel(day.isToday ? date : "\(date), \(distance.lowercased())")
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
        drawCalendarTile(in: bounds, isHovered: isHovered, isMarked: day.isToday)
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
