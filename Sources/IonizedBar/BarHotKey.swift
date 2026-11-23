import Carbon.HIToolbox

/// ⌃⌥B reaches the bar, ⌃⌥1…8 switch desktop and ⌃⌥⇧1…8 send the focused window there.
/// Through Carbon because `RegisterEventHotKey` needs no Input Monitoring permission.
@MainActor
enum BarHotKey {
    private static let signature: OSType = 0x494F4E42
    private static let barID: UInt32 = 1
    private static let switchBaseID: UInt32 = 10
    private static let moveBaseID: UInt32 = 20
    private static let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8]
    private static var onPress: ((UInt32) -> Void)?
    private static var desktopHotKeys: [EventHotKeyRef] = []

    static func register(onBar: @escaping () -> Void, onDesktop: @escaping (Int) -> Void, onMoveToDesktop: @escaping (Int) -> Void) {
        onPress = { id in
            switch id {
            case barID: onBar()
            case switchBaseID + 1...switchBaseID + 8: onDesktop(Int(id - switchBaseID))
            case moveBaseID + 1...moveBaseID + 8: onMoveToDesktop(Int(id - moveBaseID))
            default: break
            }
        }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            MainActor.assumeIsolated { BarHotKey.onPress?(id) }
            return noErr
        }, 1, &pressed, nil, nil)
        if handlerStatus != noErr { log("Could not install the hotkey handler: \(handlerStatus)") }
        _ = registerHotKey(kVK_ANSI_B, modifiers: controlKey | optionKey, id: barID)
    }

    /// Only with several desktops, so the shortcuts stay free for other apps otherwise.
    static func setDesktopCount(_ count: Int) {
        desktopHotKeys.forEach { UnregisterEventHotKey($0) }
        desktopHotKeys = []
        guard count > 1 else { return }
        for (index, key) in digitKeys.prefix(count).enumerated() {
            let number = UInt32(index + 1)
            desktopHotKeys += [
                registerHotKey(key, modifiers: controlKey | optionKey, id: switchBaseID + number),
                registerHotKey(key, modifiers: controlKey | optionKey | shiftKey, id: moveBaseID + number)
            ].compactMap { $0 }
        }
    }

    private static func registerHotKey(_ key: Int, modifiers: Int, id: UInt32) -> EventHotKeyRef? {
        var hotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(key), UInt32(modifiers), EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { log("Could not register hotkey \(id): \(status)") }
        return hotKey
    }
}
