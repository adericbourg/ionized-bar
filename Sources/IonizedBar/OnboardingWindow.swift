import AppKit
@preconcurrency import ApplicationServices

final class OnboardingWindow: NSWindow {
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 380, height: 150), styleMask: [.titled, .closable], backing: .buffered, defer: true)
        title = "Accessibility permission"
        isReleasedWhenClosed = false

        let explanation = NSTextField(wrappingLabelWithString: "IonizedBar needs the Accessibility permission to list, raise and move your windows. Open System Settings, then switch IonizedBar on in Privacy & Security > Accessibility. This window closes once it is granted.")
        let button = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openSettings))
        button.keyEquivalent = "\r"

        let stack = NSStackView(views: [explanation, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: 380)
        ])
        contentView = container
        initialFirstResponder = button
    }

    func show() {
        center()
        // The app has no Dock icon or menu bar, so nothing else brings this window forward.
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    // With no main menu, nothing maps Cmd-W to closing the window.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @objc private func openSettings() {
        // Registers the app in the Accessibility list; only the prompt call is known to do that.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
