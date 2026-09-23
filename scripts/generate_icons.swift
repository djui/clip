#!/usr/bin/env swift
import AppKit

// Generates Mac app icons plus a template menu-bar PDF.
// Run from the repo root: swift scripts/generate_icons.swift

func writePNG(size: Int, url: URL) throws {
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

func drawIcon(size: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let top = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.985, alpha: 1).cgColor
    let bottom = NSColor(srgbRed: 0.82, green: 0.82, blue: 0.86, alpha: 1).cgColor
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])

    let body = CGRect(x: size * 0.22, y: size * 0.20, width: size * 0.56, height: size * 0.62)
    let clip = CGRect(x: size * 0.36, y: size * 0.12, width: size * 0.28, height: size * 0.16)
    let radius = size * 0.06
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: clip, cornerWidth: size * 0.03, cornerHeight: size * 0.03, transform: nil))
    ctx.fillPath()

    let hole = clip.insetBy(dx: size * 0.07, dy: size * 0.045)
    ctx.setBlendMode(.destinationOut)
    ctx.addPath(CGPath(roundedRect: hole, cornerWidth: size * 0.015, cornerHeight: size * 0.015, transform: nil))
    ctx.fillPath()
    ctx.setBlendMode(.normal)

    ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    let lineX = body.minX + size * 0.08
    let lineW = body.width - size * 0.16
    let lineH = max(2, size * 0.035)
    for (index, factor) in [0.30, 0.46, 0.62].enumerated() {
        let width = index == 2 ? lineW * 0.62 : lineW
        let line = CGRect(x: lineX, y: body.minY + body.height * factor, width: width, height: lineH)
        ctx.addPath(CGPath(roundedRect: line, cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil))
    }
    ctx.fillPath()
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
    let body = CGRect(x: 3, y: 2, width: 12, height: 12)
    let clip = CGRect(x: 6, y: 12.2, width: 6, height: 3.6)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 2, cornerHeight: 2, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: clip, cornerWidth: 1, cornerHeight: 1, transform: nil))
    ctx.fillPath()
    ctx.setBlendMode(.destinationOut)
    let hole = clip.insetBy(dx: 1.4, dy: 0.9)
    ctx.addPath(CGPath(roundedRect: hole, cornerWidth: 0.6, cornerHeight: 0.6, transform: nil))
    ctx.fillPath()
    let line = CGRect(x: 5.2, y: 5.2, width: 7.6, height: 1.3)
    ctx.addPath(CGPath(roundedRect: line, cornerWidth: 0.6, cornerHeight: 0.6, transform: nil))
    ctx.fillPath()
    let line2 = CGRect(x: 5.2, y: 8.0, width: 5.2, height: 1.3)
    ctx.addPath(CGPath(roundedRect: line2, cornerWidth: 0.6, cornerHeight: 0.6, transform: nil))
    ctx.fillPath()
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

print("Wrote app icons to \(appIconDir.path)")
print("Wrote menu bar icon to \(menuBarDir.path)")
