import AppKit
import IonizedBarCore

final class SettingsWindow: AppWindow {
    private static let repositoryURL = URL(string: "https://github.com/adericbourg/ionized-bar/")!
    var onChange: ((Settings) -> Void)?
    private let groupingPopUp = NSPopUpButton()
    private let displayPopUp = NSPopUpButton()
    private let heightPopUp = NSPopUpButton()
    private let loginCheckbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)
    private let pinnedCheckbox = NSButton(checkboxWithTitle: "Keep pinned app icons visible", target: nil, action: nil)
    private let clockCheckbox = NSButton(checkboxWithTitle: "Display clock", target: nil, action: nil)
    private let secondsCheckbox = NSButton(checkboxWithTitle: "Display seconds", target: nil, action: nil)
    private let timeFormatLabel = NSTextField(labelWithString: "Time format:")
    private let timeFormatPopUp = NSPopUpButton()
    private let dateCheckbox = NSButton(checkboxWithTitle: "Display date", target: nil, action: nil)
    private let dateFormatLabel = NSTextField(labelWithString: "Date format:")
    private let dateFormatPopUp = NSPopUpButton()
    private let calendarHeading = NSTextField(labelWithString: "Calendar")
    private let firstWeekdayLabel = NSTextField(labelWithString: "First day of week:")
    private let firstWeekdayPopUp = NSPopUpButton()
    private let weekNumbersCheckbox = NSButton(checkboxWithTitle: "Show week numbers", target: nil, action: nil)
    private let jointCheckbox = NSButton(checkboxWithTitle: "Resize tiled windows together", target: nil, action: nil)

    init(settings: Settings) {
        super.init(title: "Settings", size: CGSize(width: 320, height: 160))

        groupingPopUp.addItems(withTitles: GroupingMode.allCases.map(Self.title))
        groupingPopUp.selectItem(at: GroupingMode.allCases.firstIndex(of: settings.grouping)!)
        groupingPopUp.setAccessibilityLabel("Group windows")
        displayPopUp.addItems(withTitles: TaskDisplay.allCases.map(Self.title))
        displayPopUp.selectItem(at: TaskDisplay.allCases.firstIndex(of: settings.taskDisplay)!)
        displayPopUp.setAccessibilityLabel("Show tasks as")
        heightPopUp.addItems(withTitles: BarHeight.allCases.map(Self.title))
        heightPopUp.selectItem(at: BarHeight.allCases.firstIndex(of: settings.barHeight)!)
        heightPopUp.setAccessibilityLabel("Bar height")
        timeFormatPopUp.addItems(withTitles: TimeFormat.allCases.map(Self.title))
        timeFormatPopUp.selectItem(at: TimeFormat.allCases.firstIndex(of: settings.clock.timeFormat)!)
        timeFormatPopUp.setAccessibilityLabel("Time format")
        dateFormatPopUp.addItems(withTitles: DateFormat.allCases.map(Self.title))
        dateFormatPopUp.selectItem(at: DateFormat.allCases.firstIndex(of: settings.clock.dateFormat)!)
        dateFormatPopUp.setAccessibilityLabel("Date format")
        firstWeekdayPopUp.addItems(withTitles: FirstWeekday.allCases.map(Self.title))
        firstWeekdayPopUp.selectItem(at: FirstWeekday.allCases.firstIndex(of: settings.calendar.firstWeekday)!)
        firstWeekdayPopUp.setAccessibilityLabel("First day of week")
        for popUp in [groupingPopUp, displayPopUp, heightPopUp, timeFormatPopUp, dateFormatPopUp, firstWeekdayPopUp] {
            popUp.target = self
            popUp.action = #selector(selectionChanged)
        }

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginChanged)
        loginCheckbox.setAccessibilityLabel("Start at login")

        pinnedCheckbox.state = settings.keepsPinnedVisible ? .on : .off
        pinnedCheckbox.setAccessibilityLabel("Keep pinned app icons visible")
        clockCheckbox.state = settings.clock.isShown ? .on : .off
        clockCheckbox.setAccessibilityLabel("Display clock")
        secondsCheckbox.state = settings.clock.showsSeconds ? .on : .off
        secondsCheckbox.setAccessibilityLabel("Display seconds")
        dateCheckbox.state = settings.clock.showsDate ? .on : .off
        dateCheckbox.setAccessibilityLabel("Display date")
        weekNumbersCheckbox.state = settings.calendar.showsWeekNumbers ? .on : .off
        weekNumbersCheckbox.setAccessibilityLabel("Show week numbers")
        jointCheckbox.state = settings.resizesJointWindows ? .on : .off
        jointCheckbox.setAccessibilityLabel("Resize tiled windows together")
        for checkbox in [pinnedCheckbox, clockCheckbox, secondsCheckbox, dateCheckbox, weekNumbersCheckbox, jointCheckbox] {
            checkbox.target = self
            checkbox.action = #selector(selectionChanged)
        }

        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", content: makeGeneralContent(), size: CGSize(width: 320, height: 200)))
        tabs.addTabViewItem(Self.tab("Widgets", symbol: "square.grid.2x2", content: makeWidgetsContent(), size: CGSize(width: 320, height: 320)))
        tabs.addTabViewItem(Self.tab("Windows", symbol: "macwindow", content: jointCheckbox, size: CGSize(width: 320, height: 80)))
        tabs.addTabViewItem(Self.tab("About", symbol: "info.circle", content: makeAboutContent(), size: CGSize(width: 320, height: 80)))
        toolbarStyle = .preference
        contentViewController = tabs
        updateClockRows()
        initialFirstResponder = groupingPopUp
    }

    private func makeGeneralContent() -> NSView {
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Group windows:"), groupingPopUp],
            [NSTextField(labelWithString: "Show tasks as:"), displayPopUp],
            [NSTextField(labelWithString: "Bar height:"), heightPopUp],
            [NSGridCell.emptyContentView, pinnedCheckbox],
            [NSGridCell.emptyContentView, loginCheckbox]
        ])
        grid.rowSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        return grid
    }

    private func makeWidgetsContent() -> NSView {
        let heading = NSTextField(labelWithString: "Clock")
        heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        calendarHeading.font = heading.font
        let stack = NSStackView(views: [
            heading,
            clockCheckbox,
            Self.row([secondsCheckbox], indent: 20),
            Self.row([timeFormatLabel, timeFormatPopUp], indent: 20),
            Self.row([dateCheckbox], indent: 20),
            Self.row([dateFormatLabel, dateFormatPopUp], indent: 40),
            calendarHeading,
            Self.row([firstWeekdayLabel, firstWeekdayPopUp], indent: 20),
            Self.row([weekNumbersCheckbox], indent: 20)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(20, after: stack.arrangedSubviews[5])
        return stack
    }

    private func makeAboutContent() -> NSView {
        let info = Bundle.main.infoDictionary
        let version = versionDescription(
            version: info?["CFBundleShortVersionString"] as? String,
            commit: info?["IonizedBarCommit"] as? String
        )
        let label = NSTextField(labelWithString: "IonizedBar \(version)")
        label.isSelectable = true
        let link = NSButton(title: Self.repositoryURL.absoluteString, target: self, action: #selector(openRepository))
        link.isBordered = false
        link.contentTintColor = .linkColor
        let stack = NSStackView(views: [label, link])
        stack.orientation = .vertical
        stack.alignment = .leading
        return stack
    }

    @objc private func openRepository() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    private static func row(_ views: [NSView], indent: CGFloat) -> NSStackView {
        let row = NSStackView(views: views)
        row.edgeInsets.left = indent
        return row
    }

    private static func tab(_ label: String, symbol: String, content: NSView, size: CGSize) -> NSTabViewItem {
        content.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        let controller = NSViewController()
        controller.view = container
        controller.title = label
        controller.preferredContentSize = size
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    private static func title(_ mode: GroupingMode) -> String {
        switch mode {
        case .never: "Never"
        case .whenFull: "When full"
        case .always: "Always"
        }
    }

    private static func title(_ display: TaskDisplay) -> String {
        switch display {
        case .iconOnly: "Icon only"
        case .appName: "App name"
        case .content: "Content"
        }
    }

    private static func title(_ height: BarHeight) -> String {
        switch height {
        case .extraSmall: "Extra small"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra large"
        }
    }

    private static func title(_ format: TimeFormat) -> String {
        switch format {
        case .system: "System default"
        case .twelveHour: "12-hour"
        case .twentyFourHour: "24-hour"
        }
    }

    private static func title(_ format: DateFormat) -> String {
        switch format {
        case .system: "System default"
        case .iso: "ISO (yyyy-mm-dd)"
        case .dayMonthYear: "dd/mm/yyyy"
        }
    }

    private static func title(_ weekday: FirstWeekday) -> String {
        switch weekday {
        case .system: "System default"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    override func show() {
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        super.show()
    }

    private func updateClockRows() {
        let isClockOn = clockCheckbox.state == .on
        let isDateFormatOn = isClockOn && dateCheckbox.state == .on
        secondsCheckbox.isEnabled = isClockOn
        timeFormatPopUp.isEnabled = isClockOn
        timeFormatLabel.textColor = isClockOn ? .labelColor : .disabledControlTextColor
        dateCheckbox.isEnabled = isClockOn
        dateFormatPopUp.isEnabled = isDateFormatOn
        dateFormatLabel.textColor = isDateFormatOn ? .labelColor : .disabledControlTextColor
        // The calendar opens from the clock, so with no clock it can't open.
        calendarHeading.textColor = isClockOn ? .labelColor : .disabledControlTextColor
        firstWeekdayLabel.textColor = isClockOn ? .labelColor : .disabledControlTextColor
        firstWeekdayPopUp.isEnabled = isClockOn
        weekNumbersCheckbox.isEnabled = isClockOn
    }

    @objc private func selectionChanged() {
        updateClockRows()
        onChange?(Settings(
            grouping: GroupingMode.allCases[groupingPopUp.indexOfSelectedItem],
            taskDisplay: TaskDisplay.allCases[displayPopUp.indexOfSelectedItem],
            keepsPinnedVisible: pinnedCheckbox.state == .on,
            clock: ClockSettings(
                isShown: clockCheckbox.state == .on,
                showsSeconds: secondsCheckbox.state == .on,
                timeFormat: TimeFormat.allCases[timeFormatPopUp.indexOfSelectedItem],
                showsDate: dateCheckbox.state == .on,
                dateFormat: DateFormat.allCases[dateFormatPopUp.indexOfSelectedItem]
            ),
            calendar: CalendarSettings(
                firstWeekday: FirstWeekday.allCases[firstWeekdayPopUp.indexOfSelectedItem],
                showsWeekNumbers: weekNumbersCheckbox.state == .on
            ),
            resizesJointWindows: jointCheckbox.state == .on,
            barHeight: BarHeight.allCases[heightPopUp.indexOfSelectedItem]
        ))
    }

    // Applies at once; on failure the checkbox goes back to the real status.
    @objc private func loginChanged() {
        LoginItem.set(loginCheckbox.state == .on)
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
    }
}
