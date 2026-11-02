import Carbon.HIToolbox

/// ⌃⌥B, through Carbon because `RegisterEventHotKey` needs no Input Monitoring permission.
@MainActor
enum BarHotKey {
    private static var onPress: (() -> Void)?

    static func register(onPress: @escaping () -> Void) {
        self.onPress = onPress
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { BarHotKey.onPress?() }
            return noErr
        }, 1, &pressed, nil, nil)
        var hotKey: EventHotKeyRef?
        let hotKeyStatus = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x494F4E42, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if handlerStatus != noErr || hotKeyStatus != noErr {
            log("Could not register the hotkey: handler \(handlerStatus), hotkey \(hotKeyStatus)")
        }
    }
}
