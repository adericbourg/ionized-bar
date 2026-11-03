import AppKit
import IonizedBarCore

/// Key without activating the app, like the bar in keyboard mode, so typing reaches the search field.
final class LauncherPanel: NSPanel, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    static let size = CGSize(width: 360, height: 420)
    private static let padding: CGFloat = 10
    private static let rowHeight: CGFloat = 28
    private static let rowID = NSUserInterfaceItemIdentifier("app")
    private static let editActions = [
        "x": #selector(NSText.cut(_:)), "c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)), "a": #selector(NSText.selectAll(_:))
    ]

    private let searchField = NSSearchField()
    private let scrollView = NSScrollView()
    private let table = NSTableView()
    private var list = LauncherList()
    private let onOpen: (InstalledApp) -> Void
    private let onDismiss: () -> Void

    init(onOpen: @escaping (InstalledApp) -> Void, onDismiss: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onDismiss = onDismiss
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        isMovable = false
        isReleasedWhenClosed = false
        let frosted = NSVisualEffectView()
        frosted.blendingMode = .behindWindow
        frosted.state = .active
        frosted.material = .hudWindow
        frosted.maskImage = PreviewPanel.roundedMask
        contentView = frosted

        searchField.placeholderString = "Search applications"
        searchField.delegate = self
        // The clear button. Typing goes through controlTextDidChange: this action comes later, so Return could outrun it.
        searchField.target = self
        searchField.action = #selector(queryChanged)

        let column = NSTableColumn(identifier: Self.rowID)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.headerView = nil
        table.style = .inset
        table.rowHeight = Self.rowHeight
        table.backgroundColor = .clear
        // Focus stays in the search field, so typing keeps working after a click.
        table.refusesFirstResponder = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked)
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        for view in [searchField, scrollView] { frosted.addSubview(view) }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onDismiss()
    }

    // With no main menu, nothing maps these keys to the search field.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let action = event.charactersIgnoringModifiers.flatMap({ Self.editActions[$0] }) {
            NSApp.sendAction(action, to: nil, from: self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    func show(in frame: CGRect) {
        searchField.stringValue = ""
        list.setQuery("")
        reload()
        setFrame(frame, display: false)
        let fieldHeight = searchField.intrinsicContentSize.height
        let fieldY = frame.height - Self.padding - fieldHeight
        searchField.frame = CGRect(x: Self.padding, y: fieldY, width: frame.width - 2 * Self.padding, height: fieldHeight)
        scrollView.frame = CGRect(x: 0, y: Self.padding, width: frame.width, height: max(0, fieldY - 2 * Self.padding))
        table.sizeLastColumnToFit()
        invalidateShadow()
        orderFrontRegardless()
        makeKey()
        makeFirstResponder(searchField)
    }

    func update(_ apps: [InstalledApp]) {
        list.setApps(apps)
        reload()
    }

    private func reload() {
        table.reloadData()
        showSelection()
    }

    private func showSelection() {
        table.selectRowIndexes(list.selectedIndex.map { IndexSet(integer: $0) } ?? [], byExtendingSelection: false)
        if let selectedIndex = list.selectedIndex { table.scrollRowToVisible(selectedIndex) }
    }

    func controlTextDidChange(_ notification: Notification) { queryChanged() }

    @objc private func queryChanged() {
        guard searchField.stringValue != list.query else { return }
        list.setQuery(searchField.stringValue)
        reload()
    }

    @objc private func rowClicked() {
        if list.rows.indices.contains(table.clickedRow) { onOpen(list.rows[table.clickedRow]) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:)):
            list.moveSelection(by: selector == #selector(NSResponder.moveUp(_:)) ? -1 : 1)
            showSelection()
        case #selector(NSResponder.insertNewline(_:)):
            if let app = list.selected { onOpen(app) }
        case #selector(NSResponder.cancelOperation(_:)):
            onDismiss()
        default:
            return false
        }
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int { list.rows.count }

    // Only the visible rows get here, so icons are read for those only.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.rowID, owner: nil) as? AppCell ?? AppCell(identifier: Self.rowID)
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: list.rows[row].url.path)
        cell.textField?.stringValue = list.rows[row].name
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { EmphasizedRow() }

    // The selection follows `list`: a drag over the rows must not move it away from what Return opens.
    func selectionShouldChange(in tableView: NSTableView) -> Bool { false }
}

/// The table is never first responder, which would otherwise draw the selection in the dim, unfocused style.
private final class EmphasizedRow: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set {}
    }
}

private final class AppCell: NSTableCellView {
    private static let iconSize: CGFloat = 20

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        let icon = NSImageView()
        let name = NSTextField(labelWithString: "")
        name.lineBreakMode = .byTruncatingTail
        addSubview(icon)
        addSubview(name)
        imageView = icon
        textField = name
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        imageView?.frame = CGRect(x: 4, y: ((bounds.height - Self.iconSize) / 2).rounded(), width: Self.iconSize, height: Self.iconSize)
        let nameHeight = textField?.intrinsicContentSize.height ?? 0
        let nameX = 4 + Self.iconSize + 8
        textField?.frame = CGRect(x: nameX, y: ((bounds.height - nameHeight) / 2).rounded(), width: bounds.width - nameX - 4, height: nameHeight)
    }
}

/// One panel for the whole app, above one button at a time.
@MainActor
final class LauncherController {
    private static let gap: CGFloat = 4

    private let listApps: @Sendable () -> [InstalledApp]
    private let openApp: @MainActor (URL) -> Void
    private lazy var panel = LauncherPanel(
        onOpen: { [unowned self] app in
            close()
            openApp(app.url)
        },
        onDismiss: { [unowned self] in close() }
    )
    private var button: NSView?
    private var mouseMonitors: [Any] = []

    var isOpen: Bool { button != nil }

    /// `listApps` runs off the main thread, on each open.
    init(listApps: @escaping @Sendable () -> [InstalledApp], openApp: @escaping @MainActor (URL) -> Void) {
        self.listApps = listApps
        self.openApp = openApp
    }

    func toggle(above button: NSView) {
        let isOpenHere = button === self.button
        close()
        if !isOpenHere { open(above: button) }
    }

    private func open(above button: NSView) {
        guard let window = button.window, let screen = window.screen else { return }
        self.button = button
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        // The last list shows at once, and the fresh read replaces it.
        panel.show(in: launcherFrame(button: buttonFrame, size: LauncherPanel.size, screen: screen.visibleFrame, gap: Self.gap))
        addMouseMonitors()
        let listApps = listApps
        Task { [weak self] in
            let apps = await Task.detached { listApps() }.value
            self?.panel.update(apps)
        }
    }

    func close() {
        guard button != nil else { return }
        button = nil
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors = []
        // Ordering out is what hands key back to the frontmost app, as in BarPanel.endKeyboardMode.
        panel.orderOut(nil)
    }

    // Only while open. The panel can stay key through a click in the frontmost app, which activates nothing, so
    // resign-key alone isn't enough: the global monitor gets clicks in other apps, the local one those on this app's windows.
    private func addMouseMonitors() {
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        let global = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in self?.close() }
        let local = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            guard let self else { return event }
            if event.window !== panel && !isToggleClick(event) { close() }
            return event
        }
        mouseMonitors = [global, local].compactMap { $0 }
    }

    // The button acts on mouse-up: closing on its mouse-down would make that mouse-up open the panel again.
    private func isToggleClick(_ event: NSEvent) -> Bool {
        guard let button, event.window === button.window, event.type == .leftMouseDown, !event.modifierFlags.contains(.control) else { return false }
        return button.bounds.contains(button.convert(event.locationInWindow, from: nil))
    }
}
