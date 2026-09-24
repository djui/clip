#!/usr/bin/env swift
import AppKit

// Generates Mac app icons, About/README finished icons, and a template menu-bar PDF.
// Run from the repo root: swift scripts/generate_icons.swift

func makeBitmap(size: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create bitmap")
    }
    rep.size = NSSize(width: size, height: size)
    return rep
}

func writePNG(size: Int, url: URL) throws {
    let rep = makeBitmap(size: size)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Unable to create graphics context")
    }
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    drawIcon(size: CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode PNG")
    }
    try data.write(to: url)
}

enum FinishedIconAppearance {
    case light
    case dark

    var shadowColor: CGColor {
        switch self {
        case .light:
            return srgb(0.05, 0.08, 0.18, 0.42)
        case .dark:
            return srgb(0, 0, 0, 0.72)
        }
    }
}

/// Renders a Dock-style icon: artwork clipped to a continuous corner mask, with padding and drop shadow.
func writeFinishedPNG(canvasSize: Int, iconFraction: CGFloat = 0.78, appearance: FinishedIconAppearance, url: URL) throws {
    let canvas = CGFloat(canvasSize)
    let iconSize = canvas * iconFraction
    let origin = (canvas - iconSize) / 2
    let iconRect = CGRect(x: origin, y: origin, width: iconSize, height: iconSize)
    // Continuous-corner approximation used by macOS app icons (~22.37% of edge).
    let corner = iconSize * 0.2237

    let artworkRep = makeBitmap(size: Int(iconSize.rounded()))
    NSGraphicsContext.saveGraphicsState()
    guard let artworkContext = NSGraphicsContext(bitmapImageRep: artworkRep) else {
        fatalError("Unable to create artwork context")
    }
    artworkContext.imageInterpolation = .high
    NSGraphicsContext.current = artworkContext
    drawIcon(size: CGFloat(artworkRep.pixelsWide))
    NSGraphicsContext.restoreGraphicsState()

    let artwork = NSImage(size: NSSize(width: iconSize, height: iconSize))
    artwork.addRepresentation(artworkRep)

    let canvasRep = makeBitmap(size: canvasSize)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: canvasRep) else {
        fatalError("Unable to create canvas context")
    }
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    let ctx = context.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))

    let mask = CGPath(roundedRect: iconRect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Cast a drop shadow from a temporary silhouette, then clear the fill so only the shadow remains.
    ctx.saveGState()
    // Bitmap contexts are flipped (positive Y down); positive offset casts the shadow below the icon.
    ctx.setShadow(
        offset: CGSize(width: 0, height: iconSize * 0.04),
        blur: iconSize * 0.1,
        color: appearance.shadowColor
    )
    ctx.addPath(mask)
    ctx.setFillColor(srgb(0, 0, 0, 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(mask)
    ctx.setBlendMode(.clear)
    ctx.fillPath()
    ctx.restoreGState()

    // Clipped artwork.
    ctx.saveGState()
    ctx.addPath(mask)
    ctx.clip()
    let nsRect = NSRect(x: iconRect.origin.x, y: iconRect.origin.y, width: iconRect.width, height: iconRect.height)
    artwork.draw(in: nsRect, from: .zero, operation: .sourceOver, fraction: 1)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    guard let data = canvasRep.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode finished PNG")
    }
    try data.write(to: url)
}

func srgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha).cgColor
}

func fillRound(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
}

func drawIcon(size: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [srgb(0.48, 0.56, 1.00), srgb(0.16, 0.20, 0.58)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])

    let card = CGRect(x: size * 0.23, y: size * 0.284, width: size * 0.50, height: size * 0.52)
    let radius = size * 0.058
    let sheets: [(CGFloat, CGFloat, CGColor)] = [
        (0.058, -0.088, srgb(0.78, 0.84, 0.96)),
        (0.029, -0.044, srgb(0.90, 0.93, 0.98)),
        (0, 0, srgb(0.99, 0.99, 1))
    ]
    for (dx, dy, color) in sheets {
        let sheet = card.offsetBy(dx: size * dx, dy: size * dy)
        ctx.setShadow(
            offset: CGSize(width: 0, height: size * 0.012),
            blur: size * 0.028,
            color: srgb(0.05, 0.08, 0.22, 0.28)
        )
        fillRound(ctx, sheet, radius: radius, color: color)
    }
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    let lineH = size * 0.028
    let lineX = card.minX + size * 0.07
    let lineW = card.width - size * 0.14
    let gap = size * 0.062
    var lineY = card.minY + card.height * 0.40
    if size >= 32 {
        ctx.setFillColor(srgb(0.27, 0.36, 0.66, 0.72))
        for widthFactor in [1.0, 1.0, 0.58] as [CGFloat] {
            let line = CGRect(x: lineX, y: lineY, width: lineW * widthFactor, height: lineH)
            ctx.addPath(CGPath(roundedRect: line, cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil))
            lineY += gap
        }
        ctx.fillPath()
    }

    ctx.restoreGState()
}

func writeMenuBarPDF(url: URL) {
    var mediaBox = CGRect(x: 0, y: 0, width: 18, height: 18)
    guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
        fatalError("Unable to create PDF")
    }
    ctx.beginPDFPage(nil)
    ctx.setShouldAntialias(true)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(1.45)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)

    let front = CGRect(x: 1.15, y: 1.15, width: 11.15, height: 12.15)
    let back = front.offsetBy(dx: 3.15, dy: 3.15)
    let radius: CGFloat = 2.15

    ctx.saveGState()
    ctx.addRect(mediaBox)
    let gap = front.insetBy(dx: -0.85, dy: -0.85)
    ctx.addPath(CGPath(roundedRect: gap, cornerWidth: radius + 0.4, cornerHeight: radius + 0.4, transform: nil))
    ctx.clip(using: .evenOdd)
    ctx.addPath(CGPath(roundedRect: back, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.strokePath()
    ctx.restoreGState()

    let lineH: CGFloat = 1.2
    let lineX = front.minX + 2.0
    let lineW = front.width - 4.0
    let line1 = CGRect(x: lineX, y: front.midY - 1.7, width: lineW, height: lineH)
    let line2 = CGRect(x: lineX, y: front.midY + 0.75, width: lineW * 0.62, height: lineH)
    ctx.addPath(CGPath(roundedRect: front, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.addPath(CGPath(roundedRect: line1, cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil))
    ctx.addPath(CGPath(roundedRect: line2, cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil))
    ctx.fillPath(using: .evenOdd)
    ctx.endPDFPage()
    ctx.closePDF()
}

func imageEntry(filename: String, size: String, scale: String) -> [String: Any] {
    [
        "filename": filename,
        "idiom": "mac",
        "scale": scale,
        "size": size
    ]
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconDir = root.appendingPathComponent("Clip/Assets.xcassets/AppIcon.appiconset")
let menuBarDir = root.appendingPathComponent("Clip/Assets.xcassets/MenuBarIcon.imageset")
try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuBarDir, withIntermediateDirectories: true)

struct IconSlot {
    var point: Int
    var scale: Int
    var name: String
}

let slots: [IconSlot] = [
    .init(point: 16, scale: 1, name: "icon_16x16"),
    .init(point: 16, scale: 2, name: "icon_16x16@2x"),
    .init(point: 32, scale: 1, name: "icon_32x32"),
    .init(point: 32, scale: 2, name: "icon_32x32@2x"),
    .init(point: 128, scale: 1, name: "icon_128x128"),
    .init(point: 128, scale: 2, name: "icon_128x128@2x"),
    .init(point: 256, scale: 1, name: "icon_256x256"),
    .init(point: 256, scale: 2, name: "icon_256x256@2x"),
    .init(point: 512, scale: 1, name: "icon_512x512"),
    .init(point: 512, scale: 2, name: "icon_512x512@2x")
]

var catalog: [[String: Any]] = []
for slot in slots {
    let pixels = slot.point * slot.scale
    let filename = "\(slot.name).png"
    try writePNG(size: pixels, url: appIconDir.appendingPathComponent(filename))
    catalog.append(imageEntry(
        filename: filename,
        size: "\(slot.point)x\(slot.point)",
        scale: "\(slot.scale)x"
    ))
}

let appIconJSON: [String: Any] = [
    "images": catalog,
    "info": ["author": "xcode", "version": 1]
]
let appIconData = try JSONSerialization.data(withJSONObject: appIconJSON, options: [.prettyPrinted, .sortedKeys])
try appIconData.write(to: appIconDir.appendingPathComponent("Contents.json"))

writeMenuBarPDF(url: menuBarDir.appendingPathComponent("MenuBarIcon.pdf"))

let aboutDir = root.appendingPathComponent("Clip/Assets.xcassets/AboutIcon.imageset")
try FileManager.default.createDirectory(at: aboutDir, withIntermediateDirectories: true)
try writeFinishedPNG(
    canvasSize: 512,
    appearance: .light,
    url: aboutDir.appendingPathComponent("AboutIcon.png")
)
let aboutJSON: [String: Any] = [
    "images": [[
        "filename": "AboutIcon.png",
        "idiom": "universal"
    ]],
    "info": ["author": "xcode", "version": 1]
]
let aboutData = try JSONSerialization.data(withJSONObject: aboutJSON, options: [.prettyPrinted, .sortedKeys])
try aboutData.write(to: aboutDir.appendingPathComponent("Contents.json"))
let menuJSON: [String: Any] = [
    "images": [[
        "filename": "MenuBarIcon.pdf",
        "idiom": "universal"
    ]],
    "info": ["author": "xcode", "version": 1],
    "properties": [
        "preserves-vector-representation": true,
        "template-rendering-intent": "template"
    ]
]
let menuData = try JSONSerialization.data(withJSONObject: menuJSON, options: [.prettyPrinted, .sortedKeys])
try menuData.write(to: menuBarDir.appendingPathComponent("Contents.json"))

let docsDir = root.appendingPathComponent("docs")
try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
try writeFinishedPNG(
    canvasSize: 640,
    appearance: .light,
    url: docsDir.appendingPathComponent("app-icon-light.png")
)
try writeFinishedPNG(
    canvasSize: 640,
    appearance: .dark,
    url: docsDir.appendingPathComponent("app-icon-dark.png")
)

print("Wrote app icons to \(appIconDir.path)")
print("Wrote menu bar icon to \(menuBarDir.path)")
print("Wrote about icon to \(aboutDir.path)")
print("Wrote README icons to \(docsDir.path)")
