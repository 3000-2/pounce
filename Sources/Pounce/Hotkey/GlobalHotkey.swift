import Carbon

/// Carbon over an event tap: hot keys fire on the main run loop and need no
/// extra permission, so activation stays independent of the hint-capture tap.
final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let numericID: UInt32
    private let onTrigger: () -> Void

    /// `id` must be unique per instance: every installed handler receives every
    /// hot-key event, so without the ID check any registered hot key would
    /// trigger all instances at once.
    init?(keyCode: UInt32, modifiers: UInt32, id: UInt32, onTrigger: @escaping () -> Void) {
        self.numericID = id
        self.onTrigger = onTrigger

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            var pressedID = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &pressedID
            )
            let me = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            guard pressedID.id == me.numericID else {
                // Handlers chain on the same target; returning noErr here would
                // consume the event before the matching instance ever sees it.
                return OSStatus(eventNotHandledErr)
            }
            me.onTrigger()
            return noErr
        }
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x504F_554E), id: id) // 'POUN'
        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard registerStatus == noErr else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
