import AppKit
@preconcurrency import ApplicationServices

final class OnboardingWindow: AppWindow {
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    init() {
        super.init(title: "Accessibility permission", size: CGSize(width: 380, height: 150))

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

    @objc private func openSettings() {
        // Registers the app in the Accessibility list; only the prompt call is known to do that.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
