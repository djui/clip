import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ClipboardMonitor {
    private let store: ClipboardStore
    private let settings: AppSettings
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    var ignoreNextChange = false

    init(store: ClipboardStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        if ignoreNextChange {
            ignoreNextChange = false
            return
        }
        capture(from: pasteboard)
    }

    func capture(from pasteboard: NSPasteboard) {
        guard !settings.isPaused else { return }
        guard !ClipboardPrivacy.shouldIgnore(pasteboard) else { return }

        let source = NSWorkspace.shared.frontmostApplication
        if let bundleID = source?.bundleIdentifier, bundleID == Bundle.main.bundleIdentifier {
            return
        }
        if let bundleID = source?.bundleIdentifier, settings.ignoredBundleIDs.contains(bundleID) {
            return
        }

        guard let item = Self.makeItem(from: pasteboard, source: source, store: store) else { return }
        store.ingest(item, historyLimit: settings.historyLimit)
    }

    static func makeItem(from pasteboard: NSPasteboard, source: NSRunningApplication?, store: ClipboardStore) -> ClipItem? {
        let types = pasteboard.types ?? []
        let sourceName = source?.localizedName
        let sourceID = source?.bundleIdentifier

        if let imageItem = makeImageItem(from: pasteboard, sourceID: sourceID, sourceName: sourceName, store: store) {
            return imageItem
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            let files = urls.filter(\.isFileURL)
            if !files.isEmpty {
                let thumbURL = files.first { $0.isImageFile || $0.isPDFFile }
                let thumb = thumbURL.flatMap { PreviewSupport.thumbnail(for: $0) }
                let path = thumb.flatMap { $0.pngData() }.flatMap { store.saveMedia(data: $0, ext: "png") }
                let kind: ClipItem.Kind = (files.count == 1 && files[0].isImageFile) ? .image : .file
                return ClipItem(
                    id: UUID(),
                    createdAt: Date(),
                    kind: kind,
                    plainText: files.map(\.lastPathComponent).joined(separator: ", "),
                    rtfPath: nil,
                    imagePath: path,
                    fileURLs: files,
                    colorHex: nil,
                    sourceBundleID: sourceID,
                    sourceAppName: sourceName,
                    isPinned: false,
                    contentHash: ClipItem.hash(kind: kind, text: files.first?.path, imageData: nil, files: files, colorHex: nil)
                )
            }
        }

        let rtf = pasteboard.data(forType: .rtf)
        let plain = pasteboard.string(forType: .string)
        let html = pasteboard.string(forType: .html)

        if let plain, let url = URL(string: plain.trimmingCharacters(in: .whitespacesAndNewlines)),
           let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return ClipItem(
                id: UUID(),
                createdAt: Date(),
                kind: .url,
                plainText: url.absoluteString,
                rtfPath: nil,
                imagePath: nil,
                fileURLs: [],
                colorHex: nil,
                sourceBundleID: sourceID,
                sourceAppName: sourceName,
                isPinned: false,
                contentHash: ClipItem.hash(kind: .url, text: url.absoluteString, imageData: nil, files: [], colorHex: nil)
            )
        }

        if let rtf, (plain?.isEmpty == false || html != nil) {
            let path = store.saveMedia(data: rtf, ext: "rtf")
            let text = plain ?? String(data: rtf, encoding: .utf8)
            return ClipItem(
                id: UUID(),
                createdAt: Date(),
                kind: .rtf,
                plainText: text,
                rtfPath: path,
                imagePath: nil,
                fileURLs: [],
                colorHex: nil,
                sourceBundleID: sourceID,
                sourceAppName: sourceName,
                isPinned: false,
                contentHash: ClipItem.hash(kind: .rtf, text: text, imageData: rtf, files: [], colorHex: nil)
            )
        }

        if let plain, !plain.isEmpty {
            return ClipItem(
                id: UUID(),
                createdAt: Date(),
                kind: .text,
                plainText: plain,
                rtfPath: nil,
                imagePath: nil,
                fileURLs: [],
                colorHex: nil,
                sourceBundleID: sourceID,
                sourceAppName: sourceName,
                isPinned: false,
                contentHash: ClipItem.hash(kind: .text, text: plain, imageData: nil, files: [], colorHex: nil)
            )
        }

        if types.contains(.color),
           let colors = pasteboard.readObjects(forClasses: [NSColor.self]) as? [NSColor],
           let color = colors.first {
            let hex = color.hexString
            return ClipItem(
                id: UUID(),
                createdAt: Date(),
                kind: .color,
                plainText: hex,
                rtfPath: nil,
                imagePath: nil,
                fileURLs: [],
                colorHex: hex,
                sourceBundleID: sourceID,
                sourceAppName: sourceName,
                isPinned: false,
                contentHash: ClipItem.hash(kind: .color, text: hex, imageData: nil, files: [], colorHex: hex)
            )
        }

        return nil
    }

    private static func makeImageItem(
        from pasteboard: NSPasteboard,
        sourceID: String?,
        sourceName: String?,
        store: ClipboardStore
    ) -> ClipItem? {
        let data = pasteboard.data(forType: .png)
            ?? pasteboard.data(forType: .tiff)
            ?? pasteboard.data(forType: .init("public.jpeg"))
        guard let data, let image = NSImage(data: data), let png = image.pngData() else { return nil }
        let path = store.saveMedia(data: png, ext: "png")
        let files = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []).filter(\.isFileURL)
        return ClipItem(
            id: UUID(),
            createdAt: Date(),
            kind: .image,
            plainText: nil,
            rtfPath: nil,
            imagePath: path,
            fileURLs: files,
            colorHex: nil,
            sourceBundleID: sourceID,
            sourceAppName: sourceName,
            isPinned: false,
            contentHash: ClipItem.hash(kind: .image, text: nil, imageData: png, files: files, colorHex: nil)
        )
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
