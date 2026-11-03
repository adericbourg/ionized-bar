import AppKit

/// A regular window of an app with no Dock icon and no main menu.
class AppWindow: NSWindow {
    init(title: String, size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: true)
        self.title = title
        isReleasedWhenClosed = false
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
}
