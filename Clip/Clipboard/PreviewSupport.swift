import AppKit
import PDFKit
import UniformTypeIdentifiers

enum PreviewSupport {
    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "tif", "tiff", "heic", "heif", "bmp", "ico"
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
    }

    static func thumbnail(for url: URL, pixelSize: CGSize = CGSize(width: 512, height: 512)) -> NSImage? {
        if isImageFile(url) {
            return NSImage(contentsOf: url)
        }
        if isPDF(url) {
            return pdfPageImage(url: url, size: pixelSize)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func pdfPageImage(url: URL, size: CGSize) -> NSImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        return page.thumbnail(of: size, for: .mediaBox)
    }
}

extension URL {
    var isImageFile: Bool { PreviewSupport.isImageFile(self) }
    var isPDFFile: Bool { PreviewSupport.isPDF(self) }
}
