import AppKit
import PDFKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

enum PreviewSupport {
    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "tif", "tiff", "heic", "heif", "bmp", "ico"
    ]

    static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "mpg", "mpeg"
    ]

    static func isImageFile(_ url: URL) -> Bool {
        if imageExtensions.contains(url.pathExtension.lowercased()) { return true }
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            return true
        }
        return false
    }

    static func isPDF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
            || UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true
    }

    static func isVideoFile(_ url: URL) -> Bool {
        if videoExtensions.contains(url.pathExtension.lowercased()) { return true }
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .movie) {
            return true
        }
        return false
    }

    static func isVisualMedia(_ url: URL) -> Bool {
        isImageFile(url) || isPDF(url) || isVideoFile(url)
    }

    /// Best-effort visual thumbnail. Prefer Quick Look so PDFs, images, and video frames work.
    static func thumbnail(for url: URL, pixelSize: CGSize = CGSize(width: 256, height: 256)) -> NSImage? {
        if let quickLook = quickLookThumbnail(for: url, pixelSize: pixelSize) {
            return quickLook
        }
        if isImageFile(url), let image = NSImage(contentsOf: url) {
            return image.resizedToFit(maxPixel: max(pixelSize.width, pixelSize.height))
        }
        if isPDF(url), let image = pdfPageImage(url: url, size: pixelSize) {
            return image
        }
        return nil
    }

    static func quickLookThumbnail(for url: URL, pixelSize: CGSize) -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: pixelSize,
            scale: scale,
            representationTypes: .thumbnail
        )
        var image: NSImage?
        let lock = DispatchSemaphore(value: 0)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            image = representation?.nsImage
            lock.signal()
        }
        _ = lock.wait(timeout: .now() + 1.5)
        return image
    }

    static func pdfPageImage(url: URL, size: CGSize) -> NSImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        return page.thumbnail(of: size, for: .mediaBox)
    }
}

extension URL {
    var isImageFile: Bool { PreviewSupport.isImageFile(self) }
    var isPDFFile: Bool { PreviewSupport.isPDF(self) }
    var isVideoFile: Bool { PreviewSupport.isVideoFile(self) }
    var isVisualMedia: Bool { PreviewSupport.isVisualMedia(self) }
}

extension NSImage {
    func resizedToFit(maxPixel: CGFloat) -> NSImage {
        guard size.width > 0, size.height > 0 else { return self }
        let longest = max(size.width, size.height)
        guard longest > maxPixel else { return self }
        let scale = maxPixel / longest
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let output = NSImage(size: target)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: target),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        output.unlockFocus()
        return output
    }

    func pngDataFitting(maxPixel: CGFloat) -> Data? {
        resizedToFit(maxPixel: maxPixel).pngData()
    }
}
