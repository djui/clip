import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct ClipItem: Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case text
        case rtf
        case url
        case image
        case file
        case color

        var symbolName: String {
            switch self {
            case .text: "text.alignleft"
            case .rtf: "doc.richtext"
            case .url: "link"
            case .image: "photo"
            case .file: "doc"
            case .color: "paintpalette"
            }
        }

        var title: String {
            switch self {
            case .text: "Text"
            case .rtf: "Rich Text"
            case .url: "Link"
            case .image: "Image"
            case .file: "File"
            case .color: "Color"
            }
        }
    }

    var id: UUID
    var createdAt: Date
    var kind: Kind
    var plainText: String?
    var rtfPath: String?
    var imagePath: String?
    var fileURLs: [URL]
    var colorHex: String?
    var sourceBundleID: String?
    var sourceAppName: String?
    var isPinned: Bool
    var contentHash: String

    var previewText: String {
        if let plainText, !plainText.isEmpty {
            return plainText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if kind == .file {
            return fileURLs.map(\.lastPathComponent).joined(separator: ", ")
        }
        if kind == .color, let colorHex {
            return colorHex
        }
        return kind.title
    }

    var previewImage: NSImage? {
        if let imagePath, let image = NSImage(contentsOfFile: imagePath) {
            return image
        }
        if let url = fileURLs.first {
            return PreviewSupport.thumbnail(for: url)
        }
        return nil
    }

    var richText: NSAttributedString? {
        guard let rtfPath else { return nil }
        let url = URL(fileURLWithPath: rtfPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    func matches(_ query: String) -> Bool {
        let q = query.localizedLowercase
        if previewText.localizedLowercase.contains(q) { return true }
        if sourceAppName?.localizedLowercase.contains(q) == true { return true }
        if kind.title.localizedLowercase.contains(q) { return true }
        if fileURLs.contains(where: { $0.path.localizedLowercase.contains(q) }) { return true }
        return false
    }

    func write(to pasteboard: NSPasteboard, plainText onlyPlain: Bool) {
        pasteboard.clearContents()
        var items: [any NSPasteboardWriting] = []

        if onlyPlain {
            if let plainText {
                pasteboard.setString(plainText, forType: .string)
            }
            return
        }

        if let rtfPath, let data = try? Data(contentsOf: URL(fileURLWithPath: rtfPath)) {
            pasteboard.setData(data, forType: .rtf)
            if let plainText {
                pasteboard.setString(plainText, forType: .string)
            }
            return
        }

        if let imagePath, let image = NSImage(contentsOf: URL(fileURLWithPath: imagePath)) {
            items.append(image)
        }

        if !fileURLs.isEmpty {
            items.append(contentsOf: fileURLs.map { $0 as NSURL })
        }

        if let colorHex, let color = NSColor(hex: colorHex) {
            items.append(color)
        }

        if let plainText {
            if items.isEmpty {
                pasteboard.setString(plainText, forType: .string)
                return
            }
        }

        if !items.isEmpty {
            pasteboard.writeObjects(items)
            if let plainText, pasteboard.string(forType: .string) == nil {
                pasteboard.setString(plainText, forType: .string)
            }
        } else if let plainText {
            pasteboard.setString(plainText, forType: .string)
        }
    }

    func draggingWriters() -> [any NSPasteboardWriting] {
        if !fileURLs.isEmpty {
            return fileURLs.map { $0 as NSURL }
        }

        if let imagePath, FileManager.default.fileExists(atPath: imagePath) {
            let url = URL(fileURLWithPath: imagePath)
            if let image = NSImage(contentsOf: url) {
                let item = NSPasteboardItem()
                if let tiff = image.tiffRepresentation {
                    item.setData(tiff, forType: .tiff)
                    if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                        item.setData(png, forType: .png)
                    }
                }
                item.setString(url.absoluteString, forType: .fileURL)
                return [item]
            }
            return [url as NSURL]
        }

        if let rtfPath, let data = try? Data(contentsOf: URL(fileURLWithPath: rtfPath)) {
            let item = NSPasteboardItem()
            item.setData(data, forType: .rtf)
            if let plainText {
                item.setString(plainText, forType: .string)
            }
            return [item]
        }

        if kind == .url, let plainText, let url = URL(string: plainText) {
            return [url as NSURL]
        }

        if kind == .color, let colorHex {
            let item = NSPasteboardItem()
            item.setString(colorHex, forType: .string)
            if let color = NSColor(hex: colorHex) {
                return [color, item]
            }
            return [item]
        }

        if let plainText {
            let item = NSPasteboardItem()
            item.setString(plainText, forType: .string)
            return [item]
        }

        return []
    }

    func dragPreviewImage() -> NSImage {
        if let previewImage {
            return previewImage
        }
        if kind == .color, let color = NSColor(hex: colorHex ?? "") {
            let image = NSImage(size: NSSize(width: 120, height: 80))
            image.lockFocus()
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 120, height: 80), xRadius: 10, yRadius: 10).fill()
            image.unlockFocus()
            return image
        }
        let size = NSSize(width: 148, height: 88)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(white: 0.12, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 12, yRadius: 12).fill()
        let text = (previewText as NSString)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        text.draw(
            with: NSRect(x: 10, y: 12, width: size.width - 20, height: size.height - 24),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attrs
        )
        image.unlockFocus()
        return image
    }

    static func hash(kind: Kind, text: String?, imageData: Data?, files: [URL], colorHex: String?) -> String {
        var hasher = SHA256()
        hasher.update(kind.rawValue)
        if let text {
            hasher.update(text)
        }
        if let imageData {
            hasher.update(data: imageData)
        }
        for url in files {
            hasher.update(url.absoluteString)
        }
        if let colorHex {
            hasher.update(colorHex)
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}

private extension SHA256 {
    mutating func update(_ string: String) {
        update(data: Data(string.utf8))
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8 else { return nil }
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let a, r, g, b: UInt64
        if value.count == 8 {
            a = (int & 0xFF00_0000) >> 24
            r = (int & 0x00FF_0000) >> 16
            g = (int & 0x0000_FF00) >> 8
            b = int & 0x0000_00FF
        } else {
            a = 255
            r = (int & 0xFF0000) >> 16
            g = (int & 0x00FF00) >> 8
            b = int & 0x0000FF
        }
        self.init(
            srgbRed: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        return String(
            format: "#%02X%02X%02X",
            Int(rgb.redComponent * 255),
            Int(rgb.greenComponent * 255),
            Int(rgb.blueComponent * 255)
        )
    }
}
