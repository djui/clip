import AppKit
import Foundation

@Observable
@MainActor
final class ClipboardStore {
    private(set) var items: [ClipItem] = []
    var searchQuery = ""
    var selectedID: UUID?
    private(set) var scrollGeneration = 0
    private(set) var searchFocusGeneration = 0

    var filteredItems: [ClipItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [ClipItem]
        if query.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { $0.matches(query) }
        }
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var selectedItem: ClipItem? {
        filteredItems.first { $0.id == selectedID } ?? filteredItems.first
    }

    var unpinnedCount: Int {
        items.reduce(0) { $0 + ($1.isPinned ? 0 : 1) }
    }

    private var database: ClipDatabase?
    private let mediaDirectory: URL

    init() {
        let support = Self.supportDirectory()
        mediaDirectory = support.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        database = try? ClipDatabase(url: support.appendingPathComponent("clips.sqlite"))
    }

    private static func supportDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clip = appSupport.appendingPathComponent("Clip", isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: clip.path) {
            try? fm.createDirectory(at: clip, withIntermediateDirectories: true)
            if let source = migrationSource(in: appSupport, fm: fm) {
                copyHistory(from: source, to: clip, fm: fm)
            }
        }
        return clip
    }

    private static func migrationSource(in appSupport: URL, fm: FileManager) -> URL? {
        for name in ["Notch", "Paste"] {
            let folder = appSupport.appendingPathComponent(name, isDirectory: true)
            if fm.fileExists(atPath: folder.appendingPathComponent("clips.sqlite").path) {
                return folder
            }
        }
        return nil
    }

    private static func copyHistory(from source: URL, to clip: URL, fm: FileManager) {
        let sqlite = source.appendingPathComponent("clips.sqlite")
        let destSQL = clip.appendingPathComponent("clips.sqlite")
        if fm.fileExists(atPath: sqlite.path) {
            try? fm.copyItem(at: sqlite, to: destSQL)
            if let database = try? ClipDatabase(url: destSQL) {
                try? database.rewritePathPrefix(from: source.path, to: clip.path)
            }
        }
        let media = source.appendingPathComponent("Media", isDirectory: true)
        if fm.fileExists(atPath: media.path) {
            try? fm.copyItem(at: media, to: clip.appendingPathComponent("Media", isDirectory: true))
        }
    }

    func load() {
        items = (try? database?.fetchAll()) ?? []
        if selectedID == nil {
            selectedID = filteredItems.first?.id
        }
    }

    func focusSearch() {
        searchFocusGeneration += 1
    }

    func ingest(_ item: ClipItem, historyLimit: Int) {
        if let existing = try? database?.item(withHash: item.contentHash) {
            var updated = existing
            updated.createdAt = item.createdAt
            updated.sourceAppName = item.sourceAppName ?? existing.sourceAppName
            updated.sourceBundleID = item.sourceBundleID ?? existing.sourceBundleID
            upsert(updated, historyLimit: historyLimit)
            return
        }
        upsert(item, historyLimit: historyLimit)
    }

    func togglePin(_ item: ClipItem) {
        guard var current = items.first(where: { $0.id == item.id }) else { return }
        current.isPinned.toggle()
        upsert(current, historyLimit: AppModel.shared.settings.historyLimit)
    }

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        try? database?.delete(id: item.id)
        removeMedia(for: item)
        if selectedID == item.id {
            selectedID = filteredItems.first?.id
        }
    }

    func confirmAndClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Unpinned clips will be deleted. Pinned items are kept."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            clearHistory()
        }
    }

    func clearHistory() {
        let removed = items.filter { !$0.isPinned }
        guard !removed.isEmpty else { return }
        items.removeAll { !$0.isPinned }
        try? database?.deleteUnpinned()
        removed.forEach(removeMedia)
        if let selectedID, !items.contains(where: { $0.id == selectedID }) {
            self.selectedID = filteredItems.first?.id
        }
    }

    func selectFirst() {
        selectedID = filteredItems.first?.id
        scrollGeneration += 1
    }

    func selectNext() {
        let list = filteredItems
        guard let index = list.firstIndex(where: { $0.id == selectedID }) else {
            selectedID = list.first?.id
            scrollGeneration += 1
            return
        }
        selectedID = list[min(index + 1, list.count - 1)].id
        scrollGeneration += 1
    }

    func selectPrevious() {
        let list = filteredItems
        guard let index = list.firstIndex(where: { $0.id == selectedID }) else {
            selectedID = list.first?.id
            scrollGeneration += 1
            return
        }
        selectedID = list[max(index - 1, 0)].id
        scrollGeneration += 1
    }

    func select(_ item: ClipItem) {
        selectedID = item.id
    }

    func item(at index: Int) -> ClipItem? {
        let list = filteredItems
        guard list.indices.contains(index) else { return nil }
        return list[index]
    }

    func saveMedia(data: Data, ext: String) -> String? {
        let url = mediaDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    private func upsert(_ item: ClipItem, historyLimit: Int) {
        if let index = items.firstIndex(where: { $0.id == item.id || $0.contentHash == item.contentHash }) {
            let old = items[index]
            if old.id != item.id {
                try? database?.delete(id: old.id)
            }
            items.remove(at: index)
        }
        items.insert(item, at: 0)
        try? database?.upsert(item)
        if let extras = try? database?.trim(limit: historyLimit) {
            let extraIDs = Set(extras.map(\.id))
            items.removeAll { extraIDs.contains($0.id) }
            extras.forEach(removeMedia)
        }
        if selectedID == nil || items.contains(where: { $0.id == item.id }) {
            selectedID = item.id
        }
    }

    private func removeMedia(for item: ClipItem) {
        if let imagePath = item.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        if let rtfPath = item.rtfPath {
            try? FileManager.default.removeItem(atPath: rtfPath)
        }
    }
}
