import CoreGraphics

enum HintKey {
    case char(String)
    case escape
    case delete
    case confirm
    case tab
}

/// Recognised keys are swallowed so they never reach the focused app; the tap
/// re-enables itself when the system disables it (timeout/user input).
final class HintKeyTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let onKey: (HintKey) -> Void

    init(onKey: @escaping (HintKey) -> Void) {
        self.onKey = onKey
    }

    // The tap callback holds an unretained self; tear down before it can dangle.
    deinit {
        stop()
    }

    func start() -> Bool {
        let callback: CGEventTapCallBack = { _, type, event, userData in
            guard let userData else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<HintKeyTap>.fromOpaque(userData).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown, me.handle(event: event) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        tap = nil
        source = nil
    }

    private func handle(event: CGEvent) -> Bool {
        // Cmd+C, Cmd+Tab etc. must reach the focused app — only bare keys are hints.
        if !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            return false
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch keyCode {
        case 53: onKey(.escape); return true
        case 51: onKey(.delete); return true
        case 36, 76: onKey(.confirm); return true
        case 48: onKey(.tab); return true
        default: break
        }

        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &buffer)
        if length > 0, let scalar = Unicode.Scalar(buffer[0]) {
            let character = Character(scalar)
            if character.isLetter || character.isNumber {
                onKey(.char(String(character)))
                return true
            }
        }
        return false
    }
}
