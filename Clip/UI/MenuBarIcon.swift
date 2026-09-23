import AppKit

enum MenuBarIcon {
    static func image() -> NSImage {
        if let named = NSImage(named: "MenuBarIcon") {
            named.isTemplate = true
            named.size = NSSize(width: 18, height: 18)
            named.accessibilityDescription = "Clip"
            return named
        }
        return generated()
    }

    private static func generated() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            let body = NSRect(x: 3, y: 2, width: 12, height: 12)
            NSBezierPath(roundedRect: body, xRadius: 2, yRadius: 2).fill()
            let clip = NSRect(x: 6, y: 12.5, width: 6, height: 3.5)
            NSBezierPath(roundedRect: clip, xRadius: 1, yRadius: 1).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Clip"
        return image
    }
}
