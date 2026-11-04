import AppKit
import IonizedBarCore

final class ClockView: NSView {
    private static let padding: CGFloat = 8

    var onWidthChange: (() -> Void)?
    private(set) var width: CGFloat = 0
    private var settings: ClockSettings
    private let timeLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private var maybeTick: Timer?

    init(settings: ClockSettings) {
        self.settings = settings
        super.init(frame: .zero)
        // Monospaced digits: the text doesn't jitter as the seconds change.
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        dateLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let stack = NSStackView(views: [timeLabel, dateLabel])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
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

    // Clicks go to the bar, which has the menu.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(settings newSettings: ClockSettings) {
        guard newSettings != settings else { return }
        settings = newSettings
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
        let textWidth = max(timeLabel.intrinsicContentSize.width, widest.date == nil ? 0 : dateLabel.intrinsicContentSize.width)
        width = textWidth.rounded(.up) + 2 * Self.padding
    }
}
