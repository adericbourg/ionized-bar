import AppKit
import Carbon.HIToolbox
import IonizedBarCore

/// Key without activating the app, like the bar in keyboard mode, so typing reaches the search field.
final class LauncherPanel: NSPanel, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSCollectionViewDataSource {
    static let size = CGSize(width: 620, height: 520)
    private static let padding: CGFloat = 10
    private static let rowHeight: CGFloat = 28
    private static let sidebarWidth: CGFloat = 190
    private static let sidebarRowHeight: CGFloat = 32
    private static let gridColumns = 4
    private static let gridItemHeight: CGFloat = 100
    private static let footerHeight: CGFloat = 44
    private static let footerButtonHeight: CGFloat = 28
    private static let footerButtonPadding: CGFloat = 16
    private static let rowID = NSUserInterfaceItemIdentifier("app")
    private static let sidebarRowID = NSUserInterfaceItemIdentifier("view")
    private static let gridItemID = NSUserInterfaceItemIdentifier("gridItem")
    private static let editActions = [
        "x": #selector(NSText.cut(_:)), "c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)), "a": #selector(NSText.selectAll(_:))
    ]

    private let searchField = NSSearchField()
    private let scrollView = HoverScrollView()
    private let table = NSTableView()
    private let sidebarScrollView = HoverScrollView()
    private let sidebar = SidebarTableView()
    private let gridScrollView = HoverScrollView()
    private let grid = NSCollectionView()
    private let gridLayout = NSCollectionViewFlowLayout()
    private let headerSeparator = NSBox()
    private let sidebarSeparator = NSBox()
    private let footerSeparator = NSBox()
    private lazy var restartButton = FooterButton(title: "Restart", symbolName: "arrow.clockwise", target: self, action: #selector(restartClicked))
    private lazy var shutDownButton = FooterButton(title: "Shut Down", symbolName: "power", target: self, action: #selector(shutDownClicked))
    private let emptyLabel = NSTextField(wrappingLabelWithString: "")
    private var hoveredSidebarRow = -1
    private var list = LauncherList()
    private let onOpen: (InstalledApp) -> Void
    private let onDismiss: () -> Void
    private let onPower: (PowerAction) -> Void

    init(onOpen: @escaping (InstalledApp) -> Void, onDismiss: @escaping () -> Void, onPower: @escaping (PowerAction) -> Void) {
        self.onOpen = onOpen
        self.onPower = onPower
        self.onDismiss = onDismiss
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        isMovable = false
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)
        let frosted = NSVisualEffectView()
        frosted.blendingMode = .behindWindow
        frosted.state = .active
        frosted.material = .hudWindow
        frosted.maskImage = PreviewPanel.roundedMask
        contentView = frosted

        searchField.placeholderString = "Search applications"
        searchField.setAccessibilityLabel("Search applications")
        searchField.delegate = self
        // The clear button. Typing goes through controlTextDidChange: this action comes later, so Return could outrun it.
        searchField.target = self
        searchField.action = #selector(queryChanged)

        configure(table, in: scrollView, label: "Applications", id: Self.rowID, rowHeight: Self.rowHeight, action: #selector(rowClicked))
        scrollView.onHover = { [unowned self] point in
            list.select(index: point.map(table.row(at:)) ?? -1)
            selectListedRow()
        }
        configure(sidebar, in: sidebarScrollView, label: "Application views", id: Self.sidebarRowID, rowHeight: Self.sidebarRowHeight, action: #selector(sidebarClicked))
        sidebarScrollView.onHover = { [unowned self] point in hoverSidebar(row: point.map(sidebar.row(at:)) ?? -1) }
        // Unlike the list, it takes focus, by Tab or Left. A click, Right or Return gives focus back to the search field,
        // where Up, Down and Return act on the apps.
        sidebar.refusesFirstResponder = false
        sidebar.onMove = { [unowned self] offset in moveSidebar(by: offset) }
        sidebar.onConfirm = { [unowned self] in makeFirstResponder(searchField) }
        sidebar.onFocusChange = { [unowned self] isFocused in
            sidebar.enumerateAvailableRowViews { rowView, _ in (rowView as? EmphasizedRow)?.showsFocus = isFocused }
        }

        grid.collectionViewLayout = gridLayout
        gridLayout.minimumInteritemSpacing = 0
        gridLayout.minimumLineSpacing = 0
        gridLayout.sectionInset = NSEdgeInsets(top: 0, left: Self.padding, bottom: 0, right: Self.padding)
        grid.register(GridItem.self, forItemWithIdentifier: Self.gridItemID)
        grid.dataSource = self
        grid.backgroundColors = [.clear]
        grid.setAccessibilityLabel(LauncherView.favorites.title)
        gridScrollView.documentView = grid
        gridScrollView.hasVerticalScroller = true
        gridScrollView.drawsBackground = false
        gridScrollView.onHover = { [unowned self] point in
            list.select(index: point.flatMap(grid.indexPathForItem(at:))?.item ?? -1)
            selectListedRow()
        }

        headerSeparator.boxType = .separator
        sidebarSeparator.boxType = .separator
        footerSeparator.boxType = .separator
        emptyLabel.alignment = .center
        searchField.nextKeyView = sidebar
        sidebar.nextKeyView = restartButton
        restartButton.nextKeyView = shutDownButton
        shutDownButton.nextKeyView = searchField
        for view in [searchField, headerSeparator, sidebarScrollView, sidebarSeparator, scrollView, gridScrollView, emptyLabel, footerSeparator, restartButton, shutDownButton] { frosted.addSubview(view) }
    }

    private func configure(_ table: NSTableView, in scrollView: NSScrollView, label: String, id: NSUserInterfaceItemIdentifier, rowHeight: CGFloat, action: Selector) {
        let column = NSTableColumn(identifier: id)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.headerView = nil
        table.style = .inset
        table.rowHeight = rowHeight
        table.backgroundColor = .clear
        table.setAccessibilityLabel(label)
        // Focus stays in the search field, so typing keeps working after a click.
        table.refusesFirstResponder = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = action
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { onDismiss() }

    override func resignKey() {
        super.resignKey()
        onDismiss()
    }

    // With no main menu, nothing maps these keys to the search field.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock) == .command,
           let action = event.charactersIgnoringModifiers.flatMap({ Self.editActions[$0.lowercased()] }) {
            NSApp.sendAction(action, to: nil, from: self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    func show(in frame: CGRect, favorites: [InstalledApp]) {
        searchField.stringValue = ""
        list.reset(favorites: favorites)
        setFrame(frame, display: false)
        let fieldHeight = searchField.intrinsicContentSize.height
        let fieldY = frame.height - Self.padding - fieldHeight
        searchField.frame = CGRect(x: Self.padding, y: fieldY, width: frame.width - 2 * Self.padding, height: fieldHeight)
        let bodyY = Self.footerHeight + 1
        let bodyHeight = max(0, fieldY - Self.padding - bodyY)
        headerSeparator.frame = CGRect(x: 0, y: fieldY - Self.padding, width: frame.width, height: 1)
        footerSeparator.frame = CGRect(x: 0, y: Self.footerHeight, width: frame.width, height: 1)
        sidebarScrollView.frame = CGRect(x: 0, y: bodyY, width: Self.sidebarWidth, height: bodyHeight)
        sidebarSeparator.frame = CGRect(x: Self.sidebarWidth, y: bodyY, width: 1, height: bodyHeight)
        var nextFooterMaxX = frame.width - Self.padding
        for button in [shutDownButton, restartButton] {
            let width = button.intrinsicContentSize.width + Self.footerButtonPadding
            button.frame = CGRect(x: nextFooterMaxX - width, y: ((Self.footerHeight - Self.footerButtonHeight) / 2).rounded(), width: width, height: Self.footerButtonHeight)
            nextFooterMaxX = button.frame.minX - Self.padding / 2
        }
        let content = CGRect(x: Self.sidebarWidth + 1, y: bodyY, width: max(0, frame.width - Self.sidebarWidth - 1), height: bodyHeight)
        scrollView.frame = content
        gridScrollView.frame = content
        gridLayout.itemSize = CGSize(
            width: ((gridScrollView.contentSize.width - 2 * Self.padding) / CGFloat(Self.gridColumns)).rounded(.down),
            height: Self.gridItemHeight
        )
        let emptyHeight = 2 * emptyLabel.intrinsicContentSize.height
        emptyLabel.frame = CGRect(x: content.minX + 2 * Self.padding, y: (content.midY - emptyHeight / 2).rounded(), width: content.width - 4 * Self.padding, height: emptyHeight)
        reload()
        table.sizeLastColumnToFit()
        sidebar.sizeLastColumnToFit()
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
        grid.reloadData()
        sidebar.reloadData()
        sidebar.selectRowIndexes(list.sidebarItems.firstIndex(of: list.view).map { IndexSet(integer: $0) } ?? [], byExtendingSelection: false)
        scrollView.isHidden = list.showsGrid
        gridScrollView.isHidden = !list.showsGrid
        emptyLabel.stringValue = list.hasNoFavorites ? LauncherList.noFavoritesMessage : LauncherList.noMatchMessage
        emptyLabel.isHidden = !list.hasNoMatch && !list.hasNoFavorites
        showSelection()
    }

    private func selectListedRow() {
        table.selectRowIndexes(list.selectedIndex.map { IndexSet(integer: $0) } ?? [], byExtendingSelection: false)
        for case let item as GridItem in grid.visibleItems() {
            item.isCurrent = grid.indexPath(for: item)?.item == list.selectedIndex
        }
    }

    private func hoverSidebar(row: Int) {
        guard row != hoveredSidebarRow else { return }
        (sidebar.rowView(atRow: hoveredSidebarRow, makeIfNecessary: false) as? EmphasizedRow)?.isHovered = false
        hoveredSidebarRow = row
        (sidebar.rowView(atRow: row, makeIfNecessary: false) as? EmphasizedRow)?.isHovered = true
    }

    private func showSelection() {
        selectListedRow()
        guard let selectedIndex = list.selectedIndex else { return }
        if list.showsGrid {
            grid.scrollToItems(at: [IndexPath(item: selectedIndex, section: 0)], scrollPosition: .nearestHorizontalEdge)
        } else {
            table.scrollRowToVisible(selectedIndex)
        }
    }

    private func announce(_ text: String) {
        // On the panel: it can't become main, so the usual NSApp.mainWindow is nil here.
        NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [
            .announcement: text,
            .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
    }

    func controlTextDidChange(_ notification: Notification) { queryChanged() }

    @objc private func queryChanged() {
        guard searchField.stringValue != list.query else { return }
        list.setQuery(searchField.stringValue)
        reload()
        announce(list.resultsAnnouncement)
    }

    @objc private func rowClicked() {
        if list.rows.indices.contains(table.clickedRow) { onOpen(list.rows[table.clickedRow]) }
    }

    @objc private func sidebarClicked() {
        guard list.sidebarItems.indices.contains(sidebar.clickedRow) else { return }
        pick(list.sidebarItems[sidebar.clickedRow])
        makeFirstResponder(searchField)
    }

    /// The view follows the keys: focus stays in the sidebar, so nothing is lost by passing over a view.
    private func moveSidebar(by offset: Int) {
        let items = list.sidebarItems
        guard let current = items.firstIndex(of: list.view), items.indices.contains(current + offset) else { return }
        pick(items[current + offset])
        sidebar.scrollRowToVisible(current + offset)
    }

    private func pick(_ view: LauncherView) {
        searchField.stringValue = ""
        list.setView(view)
        reload()
        announce(list.viewAnnouncement)
    }

    @objc private func restartClicked() { onPower(.restart) }

    @objc private func shutDownClicked() { onPower(.shutDown) }

    private func selectionMoved() {
        showSelection()
        if let selected = list.selected { announce(selected.name) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:)):
            let offset = selector == #selector(NSResponder.moveUp(_:)) ? -1 : 1
            if list.showsGrid {
                list.moveGridSelection(byRows: offset, columns: Self.gridColumns)
            } else {
                list.moveSelection(by: offset)
            }
            selectionMoved()
        // With a query typed, Left and Right stay with the search field's text cursor.
        case #selector(NSResponder.moveLeft(_:)) where list.query.isEmpty:
            if list.showsGrid, let selectedIndex = list.selectedIndex, selectedIndex % Self.gridColumns != 0 {
                list.moveSelection(by: -1)
                selectionMoved()
            } else {
                makeFirstResponder(sidebar)
            }
        case #selector(NSResponder.moveRight(_:)) where list.showsGrid:
            list.moveSelection(by: 1)
            selectionMoved()
        case #selector(NSResponder.insertNewline(_:)):
            // A held Return that opened the panel from the launcher button would otherwise open the top app on repeat.
            if NSApp.currentEvent?.isARepeat != true, let app = list.selected { onOpen(app) }
        case #selector(NSResponder.cancelOperation(_:)):
            onDismiss()
        default:
            return false
        }
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int { tableView === sidebar ? list.sidebarItems.count : list.rows.count }

    // Only the visible rows get here, so icons are read for those only.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === sidebar {
            let cell = tableView.makeView(withIdentifier: Self.sidebarRowID, owner: nil) as? AppCell ?? AppCell(identifier: Self.sidebarRowID)
            let item = list.sidebarItems[row]
            cell.imageView?.image = NSImage(systemSymbolName: item.symbolName, accessibilityDescription: nil)
            cell.imageView?.contentTintColor = .labelColor
            cell.textField?.stringValue = item.title
            return cell
        }
        let cell = tableView.makeView(withIdentifier: Self.rowID, owner: nil) as? AppCell ?? AppCell(identifier: Self.rowID)
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: list.rows[row].url.path)
        cell.textField?.stringValue = list.rows[row].name
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = EmphasizedRow()
        if tableView === sidebar {
            let item = list.sidebarItems[row]
            rowView.setAccessibilityLabel(item.title)
            rowView.hasDivider = item == .all
            rowView.isHovered = row == hoveredSidebarRow
            rowView.showsFocus = firstResponder === sidebar
        } else {
            rowView.setAccessibilityLabel(list.rows[row].name)
        }
        return rowView
    }

    // The selection follows `list`: a drag over the rows must not move it away from what Return opens.
    func selectionShouldChange(in tableView: NSTableView) -> Bool { false }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        list.showsGrid ? list.rows.count : 0
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: Self.gridItemID, for: indexPath)
        if let item = item as? GridItem {
            let app = list.rows[indexPath.item]
            item.show(app, isCurrent: indexPath.item == list.selectedIndex) { [unowned self] in onOpen(app) }
        }
        return item
    }
}

private extension LauncherView {
    var symbolName: String {
        switch self {
        case .favorites: "bookmark"
        case .all: "square.grid.2x2"
        case .category(.development): "hammer"
        case .category(.education): "graduationcap"
        case .category(.games): "gamecontroller"
        case .category(.graphics): "paintpalette"
        case .category(.internet): "globe"
        case .category(.multimedia): "play.rectangle"
        case .category(.office): "doc.text"
        case .category(.utilities): "wrench.and.screwdriver"
        case .category(.other): "ellipsis.circle"
        }
    }
}

/// Reports the pointer over its document, or nil when it leaves. Only real pointer events do: arrow keys scrolling
/// under a still pointer must not take the selection back. The wheel counts: it brings another row under a still pointer.
private final class HoverScrollView: NSScrollView {
    var onHover: ((CGPoint?) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Always active: this app is never the active one while the panel is open.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseMoved(with event: NSEvent) { report(event.locationInWindow) }

    override func mouseExited(with event: NSEvent) { onHover?(nil) }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        if let window { report(window.mouseLocationOutsideOfEventStream) }
    }

    private func report(_ locationInWindow: CGPoint) {
        onHover?(documentView?.convert(locationInWindow, from: nil))
    }
}

/// The table is never first responder, which would otherwise draw the selection in the dim, unfocused style.
private final class EmphasizedRow: NSTableRowView {
    private static let insetStylePadding: CGFloat = 10

    var isHovered = false { didSet { needsDisplay = true } }
    var hasDivider = false
    var showsFocus = false { didSet { needsDisplay = true } }

    override var isEmphasized: Bool {
        get { true }
        set {}
    }

    override func drawSelection(in dirtyRect: NSRect) {
        super.drawSelection(in: dirtyRect)
        guard showsFocus else { return }
        NSColor.labelColor.setStroke()
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: Self.insetStylePadding + 1, dy: 1), xRadius: 4, yRadius: 4)
        outline.lineWidth = 2
        outline.stroke()
    }

    override func drawBackground(in dirtyRect: NSRect) {
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: Self.insetStylePadding, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        if hasDivider {
            NSColor.separatorColor.setFill()
            CGRect(x: Self.insetStylePadding, y: isFlipped ? bounds.maxY - 1 : 0, width: bounds.width - 2 * Self.insetStylePadding, height: 1).fill()
        }
    }
}

/// Reports the keys it acts on, so that the view follows them instead of the table's own selection.
private final class SidebarTableView: NSTableView {
    var onMove: ((Int) -> Void)?
    var onConfirm: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_UpArrow: onMove?(-1)
        case kVK_DownArrow: onMove?(1)
        case kVK_RightArrow, kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space: onConfirm?()
        case kVK_Escape: window?.cancelOperation(nil)
        default: super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome { onFocusChange?(true) }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign { onFocusChange?(false) }
        return didResign
    }
}

private final class FooterButton: NSButton {
    private var isHovered = false { didSet { needsDisplay = true } }

    // Without this, Tab skips buttons unless the user turned on macOS's full keyboard navigation.
    override var canBecomeKeyView: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: performClick(nil)
        case kVK_Escape: window?.cancelOperation(nil)
        default: super.keyDown(with: event)
        }
    }

    init(title: String, symbolName: String, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        imagePosition = .imageLeading
        contentTintColor = .labelColor
        isBordered = false
        // Always active: this app is never the active one while the panel is open.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) { isHovered = true }

    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        }
        super.draw(dirtyRect)
    }
}

private final class GridItem: NSCollectionViewItem {
    var isCurrent = false {
        didSet { (view as? GridItemView)?.isCurrent = isCurrent }
    }

    override func loadView() { view = GridItemView() }

    func show(_ app: InstalledApp, isCurrent: Bool, onPress: @escaping () -> Void) {
        guard let view = view as? GridItemView else { return }
        view.show(app, onPress: onPress)
        self.isCurrent = isCurrent
    }
}

/// A button for VoiceOver. The hover and the highlight come from the panel, like the list's selection.
private final class GridItemView: NSView {
    private static let iconSize: CGFloat = 48
    private static let inset: CGFloat = 4

    private let icon = NSImageView()
    private let name = NSTextField(wrappingLabelWithString: "")
    private var onPress: (() -> Void)?
    var isCurrent = false {
        didSet {
            name.textColor = isCurrent ? .alternateSelectedControlTextColor : .labelColor
            needsDisplay = true
        }
    }

    init() {
        super.init(frame: .zero)
        icon.setAccessibilityElement(false)
        name.setAccessibilityElement(false)
        name.alignment = .center
        name.maximumNumberOfLines = 2
        name.cell?.truncatesLastVisibleLine = true
        addSubview(icon)
        addSubview(name)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show(_ app: InstalledApp, onPress: @escaping () -> Void) {
        icon.image = NSWorkspace.shared.icon(forFile: app.url.path)
        name.stringValue = app.name
        setAccessibilityLabel(app.name)
        self.onPress = onPress
    }

    override func layout() {
        super.layout()
        let iconY = bounds.height - Self.iconSize - 2 * Self.inset
        icon.frame = CGRect(x: ((bounds.width - Self.iconSize) / 2).rounded(), y: iconY, width: Self.iconSize, height: Self.iconSize)
        name.frame = CGRect(x: Self.inset, y: Self.inset, width: bounds.width - 2 * Self.inset, height: iconY - Self.inset)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isCurrent else { return }
        NSColor.selectedContentBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: Self.inset / 2, dy: Self.inset / 2), xRadius: 6, yRadius: 6).fill()
    }

    // Keeps the icon and the name out of event dispatch, as in EntryView.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    // Handled here so that the mouse-up comes here too: the collection view would otherwise track the click.
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onPress?() }
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }
}

private final class AppCell: NSTableCellView {
    private static let iconSize: CGFloat = 20

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        let icon = NSImageView()
        icon.setAccessibilityElement(false)
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
    private let favorites: @MainActor () -> [InstalledApp]
    private let openApp: @MainActor (URL) -> Void
    private lazy var panel = LauncherPanel(
        onOpen: { [unowned self] app in
            close()
            openApp(app.url)
        },
        onDismiss: { [unowned self] in close() },
        onPower: { [unowned self] action in
            close()
            showPowerDialog(action)
        }
    )
    private var button: NSView?
    private var mouseMonitors: [Any] = []

    var isOpen: Bool { button != nil }

    /// `listApps` runs off the main thread, on each open.
    init(listApps: @escaping @Sendable () -> [InstalledApp], favorites: @escaping @MainActor () -> [InstalledApp], openApp: @escaping @MainActor (URL) -> Void) {
        self.listApps = listApps
        self.favorites = favorites
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
        panel.show(in: launcherFrame(button: buttonFrame, size: LauncherPanel.size, screen: screen.visibleFrame, gap: Self.gap), favorites: favorites())
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
