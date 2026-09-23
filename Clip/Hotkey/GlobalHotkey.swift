import Carbon
import Foundation

final class GlobalHotkey {
    private let identifier: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    private static var handlerRef: EventHandlerRef?
    private static var instances: [UInt32: GlobalHotkey] = [:]

    init(id: UInt32) {
        identifier = id
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        unregister()
        callback = handler
        Self.installSharedHandlerIfNeeded()
        Self.instances[identifier] = self

        let hotKeyID = EventHotKeyID(signature: 0x434C4950, id: identifier)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        callback = nil
        if Self.instances[identifier] === self {
            Self.instances.removeValue(forKey: identifier)
        }
    }

    deinit {
        unregister()
    }

    private static func installSharedHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return noErr }
                GlobalHotkey.instances[hotKeyID.id]?.callback?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )
    }
}
