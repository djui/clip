import CoreGraphics

enum SyntheticPaste {
    static let marker: Int64 = 0x434C4950

    static func postCommandV() {
        HoldPasteMonitor.current?.beginIgnoring(2)
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 0x09
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.setIntegerValueField(.eventSourceUserData, value: marker)
        up.setIntegerValueField(.eventSourceUserData, value: marker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }
}
