import AppKit
import IonizedBarCore

final class SettingsWindow: NSWindow {
    var onChange: ((Settings) -> Void)?
    private let groupingPopUp = NSPopUpButton()
    private let displayPopUp = NSPopUpButton()
    private let loginCheckbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)

    init(settings: Settings) {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 320, height: 130), styleMask: [.titled, .closable], backing: .buffered, defer: true)
        title = "Settings"
        isReleasedWhenClosed = false

        groupingPopUp.addItems(withTitles: GroupingMode.allCases.map(Self.title))
        groupingPopUp.selectItem(at: GroupingMode.allCases.firstIndex(of: settings.grouping)!)
        groupingPopUp.setAccessibilityLabel("Group windows")
        displayPopUp.addItems(withTitles: TaskDisplay.allCases.map(Self.title))
        displayPopUp.selectItem(at: TaskDisplay.allCases.firstIndex(of: settings.taskDisplay)!)
        displayPopUp.setAccessibilityLabel("Show tasks as")
        for popUp in [groupingPopUp, displayPopUp] {
            popUp.target = self
            popUp.action = #selector(selectionChanged)
        }

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginChanged)
        loginCheckbox.setAccessibilityLabel("Start at login")

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Group windows:"), groupingPopUp],
            [NSTextField(labelWithString: "Show tasks as:"), displayPopUp],
            [NSGridCell.emptyContentView, loginCheckbox]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        let container = NSView()
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        contentView = container
        initialFirstResponder = groupingPopUp
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

    func show() {
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        center()
        // The app has no Dock icon or menu bar, so nothing else brings this window forward.
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    // With no main menu, nothing maps Cmd-W to closing the window.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, event.charactersIgnoringModifiers == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @objc private func selectionChanged() {
        onChange?(Settings(
            grouping: GroupingMode.allCases[groupingPopUp.indexOfSelectedItem],
            taskDisplay: TaskDisplay.allCases[displayPopUp.indexOfSelectedItem]
        ))
    }

    // Applies at once; on failure the checkbox goes back to the real status.
    @objc private func loginChanged() {
        LoginItem.set(loginCheckbox.state == .on)
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
    }
}
