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
            let front = NSRect(x: 1.15, y: 1.15, width: 11.15, height: 12.15)
            let back = front.offsetBy(dx: 3.15, dy: 3.15)
            let radius: CGFloat = 2.15
            NSGraphicsContext.current?.saveGraphicsState()
            let clip = NSBezierPath(rect: rect)
            let gap = front.insetBy(dx: -0.85, dy: -0.85)
            clip.append(NSBezierPath(roundedRect: gap, xRadius: radius + 0.4, yRadius: radius + 0.4))
            clip.windingRule = .evenOdd
            clip.addClip()
            NSColor.black.setStroke()
            let backPath = NSBezierPath(roundedRect: back, xRadius: radius, yRadius: radius)
            backPath.lineWidth = 1.45
            backPath.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()

            NSColor.black.setFill()
            let frontPath = NSBezierPath(roundedRect: front, xRadius: radius, yRadius: radius)
            let lineH: CGFloat = 1.2
            let lineX = front.minX + 2
            let lineW = front.width - 4
            frontPath.append(NSBezierPath(
                roundedRect: NSRect(x: lineX, y: front.midY - 1.7, width: lineW, height: lineH),
                xRadius: lineH / 2,
                yRadius: lineH / 2
            ))
            frontPath.append(NSBezierPath(
                roundedRect: NSRect(x: lineX, y: front.midY + 0.75, width: lineW * 0.62, height: lineH),
                xRadius: lineH / 2,
                yRadius: lineH / 2
            ))
            frontPath.windingRule = .evenOdd
            frontPath.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Clip"
        return image
    }
}
