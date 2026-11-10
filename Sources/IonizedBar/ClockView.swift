import AppKit
import IonizedBarCore

final class ClockView: BarButton {
    private static let padding: CGFloat = 8
    private static let singleLineSpacing: CGFloat = 6

    var onWidthChange: (() -> Void)?
    private(set) var width: CGFloat = 0
    private var settings: ClockSettings
    private var barHeight: BarHeight
    private let timeLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    private var maybeTick: Timer?

    init(settings: ClockSettings, barHeight: BarHeight, manager: BarManager) {
        self.settings = settings
        self.barHeight = barHeight
        super.init(manager: manager)
        stack.addArrangedSubview(timeLabel)
        stack.addArrangedSubview(dateLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        for name in [NSNotification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, NSLocale.currentLocaleDidChangeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(systemChanged), name: name, object: nil)
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemChanged), name: NSWorkspace.didWakeNotification, object: nil)
        measure()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // Read as one element: its label spells out the date, and the labels inside would read it digit by digit.
    override func accessibilityChildren() -> [Any]? { [] }

    override var isDraggable: Bool { false }

    override func performClickAction() {
        manager.preview.dismiss()
        (window as? BarPanel)?.endKeyboardMode()
        manager.calendar.toggle(above: self, settings: manager.settings.calendar)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isHovered else { return }
        NSColor.labelColor.withAlphaComponent(0.1).setFill()
        let tile = bounds.insetBy(dx: Self.focusRingInset, dy: Self.focusRingInset)
        NSBezierPath(roundedRect: tile, xRadius: 4, yRadius: 4).fill()
        strokeHairline(around: tile)
    }

    func update(settings newSettings: ClockSettings, barHeight newBarHeight: BarHeight) {
        guard newSettings != settings || newBarHeight != barHeight else { return }
        settings = newSettings
        barHeight = newBarHeight
        measure()
        refresh()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refresh()
    }

    // A locale change can change the format, and so the width. The bar has to make room.
    @objc private func systemChanged() {
        let previousWidth = width
        measure()
        refresh()
        if width != previousWidth { onWidthChange?() }
    }

    private func refresh() {
        let now = Date()
        let text = clockText(date: now, settings: settings)
        timeLabel.stringValue = text.time
        dateLabel.stringValue = text.date ?? ""
        dateLabel.isHidden = text.date == nil
        setAccessibilityLabel(clockAccessibilityLabel(date: now, settings: settings))
        maybeTick?.invalidate()
        maybeTick = nil
        guard window != nil else { return }
        let tick = Timer(fire: nextClockTick(after: now, showsSeconds: settings.showsSeconds), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        tick.tolerance = 0.05
        RunLoop.main.add(tick, forMode: .common)
        maybeTick = tick
    }

    // On a fixed date rather than the current one, so the bar's tasks don't move as the time changes.
    private func measure() {
        let widest = clockText(date: clockWidestDate, settings: settings, timeZone: TimeZone(identifier: "UTC")!)
        timeLabel.stringValue = widest.time
        dateLabel.stringValue = widest.date ?? ""
        // Monospaced digits: the text doesn't jitter as the seconds change.
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13 * barHeight.scale, weight: .regular)
        dateLabel.font = .monospacedDigitSystemFont(ofSize: 11 * barHeight.scale, weight: .regular)
        // The date goes beside the time when the two lines don't fit the bar's tile.
        let isSingleLine = widest.date != nil
            && timeLabel.intrinsicContentSize.height + dateLabel.intrinsicContentSize.height > barHeight.points - 2 * Self.focusRingInset
        if isSingleLine { dateLabel.font = timeLabel.font }
        stack.orientation = isSingleLine ? .horizontal : .vertical
        stack.spacing = isSingleLine ? Self.singleLineSpacing : 0
        let dateWidth = widest.date == nil ? 0 : dateLabel.intrinsicContentSize.width
        let textWidth = isSingleLine
            ? timeLabel.intrinsicContentSize.width + Self.singleLineSpacing + dateWidth
            : max(timeLabel.intrinsicContentSize.width, dateWidth)
        width = textWidth.rounded(.up) + 2 * Self.padding
    }
}
