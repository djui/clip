import AppKit
import Carbon
import Foundation

struct KeyboardShortcut: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let defaultOpen = KeyboardShortcut(
        keyCode: 9,
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    static let defaultPlainPaste = KeyboardShortcut(
        keyCode: 36,
        carbonModifiers: UInt32(shiftKey)
    )

    static let unset = KeyboardShortcut(
        keyCode: UInt32.max,
        carbonModifiers: 0
    )

    var isSet: Bool {
        keyCode != UInt32.max
    }

    var isPlainCommandV: Bool {
        keyCode == 9 && carbonModifiers == UInt32(cmdKey)
    }

    var nsEventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags
    }

    var display: String {
        guard isSet else { return "None" }
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    var menuKeyEquivalent: String {
        Self.menuEquivalent(for: keyCode)
    }

    var isValidGlobal: Bool {
        isSet
            && !isPlainCommandV
            && carbonModifiers & UInt32(cmdKey | optionKey | controlKey) != 0
            && keyCode != 0x35
    }

    var isValidLocal: Bool {
        isSet && carbonModifiers != 0 && keyCode != 0x35
    }

    func matches(_ event: NSEvent) -> Bool {
        guard isSet else { return false }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        let code = UInt32(event.keyCode)
        let keyMatches = code == keyCode || (keyCode == 36 && code == 76) || (keyCode == 76 && code == 36)
        return keyMatches && carbon == carbonModifiers
    }

    static func from(event: NSEvent, allowShiftOnly: Bool = false) -> KeyboardShortcut? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        let shortcut = KeyboardShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
        if allowShiftOnly {
            return shortcut.isValidLocal ? shortcut : nil
        }
        return shortcut.isValidGlobal ? shortcut : nil
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return menuEquivalent(for: keyCode).uppercased()
        }
    }

    private static func menuEquivalent(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 25: return "9"
        case 26: return "7"
        case 28: return "8"
        case 29: return "0"
        case 31: return "o"
        case 32: return "u"
        case 34: return "i"
        case 35: return "p"
        case 37: return "l"
        case 38: return "j"
        case 40: return "k"
        case 45: return "n"
        case 46: return "m"
        case 49: return " "
        default: return ""
        }
    }
}
