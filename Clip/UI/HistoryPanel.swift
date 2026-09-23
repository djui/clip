import AppKit
import SwiftUI

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HistoryPanelController {
    private var panel: KeyablePanel?
    private var keyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private(set) var targetApp: NSRunningApplication?
    var searchFieldFocused = false

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            showNearMouse()
        }
    }

    func showNearMouse() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApp = front
        }
        let store = AppModel.shared.store
        store.searchQuery = ""
        store.selectFirst()
        let panel = ensurePanel()
        let size = panel.frame.size
        panel.setFrame(frameNearMouse(size: size), display: false)
        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitors()
        AppModel.shared.hold.setHistoryVisible(true)
        DispatchQueue.main.async {
            store.focusSearch()
        }
    }

    func hide() {
        removeMonitors()
        panel?.orderOut(nil)
        AppModel.shared.hold.setHistoryVisible(false)
        searchFieldFocused = false
    }

    func paste(_ item: ClipItem, plainText: Bool) {
        let target = targetApp
        hide()
        PasteService.paste(item, plainText: plainText, into: target)
    }

    func pasteSelected(plainText: Bool) {
        guard let item = AppModel.shared.store.selectedItem else { return }
        paste(item, plainText: plainText)
    }

    func openSettings() {
        hide()
        SettingsWindowController.shared.show()
    }

    private func ensurePanel() -> KeyablePanel {
        if let panel { return panel }
        let root = HistoryView()
            .environment(AppModel.shared.store)
            .environment(AppModel.shared.settings)
        let hosting = NSHostingController(rootView: root)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        let size = NSSize(width: 440, height: 520)
        let cornerRadius: CGFloat = 18
        let container = NSViewController()
        container.addChild(hosting)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            glass.contentView = hosting.view
            container.view = glass
        } else {
            container.view = hosting.view
        }
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = container
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Glass already provides depth; the window shadow draws a hard 1px rim on rounded panels.
        panel.hasShadow = !isGlassPanel(container.view)
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.setContentSize(size)
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            contentView.layer?.cornerRadius = cornerRadius
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true
            contentView.layer?.borderWidth = 0
            contentView.layer?.borderColor = nil
        }
        panel.invalidateShadow()
        self.panel = panel
        return panel
    }

    private func isGlassPanel(_ view: NSView) -> Bool {
        if #available(macOS 26.0, *) {
            return view is NSGlassEffectView
        }
        return false
    }

    private func frameNearMouse(size: NSSize) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 8)
        if origin.y < visible.minY {
            origin.y = min(mouse.y + 12, visible.maxY - size.height)
        }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        return NSRect(origin: origin, size: size)
    }

    private func installMonitors() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            return self.handleKey(event) ? nil : event
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, self.clickIsOutside() else { return event }
            self.hide()
            return nil
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, self.clickIsOutside() else { return }
            self.hide()
        }
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func clickIsOutside() -> Bool {
        guard let panel, panel.isVisible else { return false }
        return !panel.frame.contains(NSEvent.mouseLocation)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let store = AppModel.shared.store
        let settings = AppModel.shared.settings
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])

        if event.keyCode == 53 {
            if flags.isEmpty, !store.searchQuery.isEmpty {
                store.searchQuery = ""
                store.selectFirst()
            } else {
                hide()
            }
            return true
        }

        if flags.contains(.command), let number = commandNumber(from: event), (1...9).contains(number) {
            if let item = store.item(at: number - 1) {
                paste(item, plainText: flags.contains(.shift) || flags.contains(.option))
            }
            return true
        }

        if settings.plainPasteShortcut.matches(event) {
            pasteSelected(plainText: true)
            return true
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            pasteSelected(plainText: flags.contains(.shift) || flags.contains(.option))
            return true
        }

        if event.keyCode == 125 || event.keyCode == 124 {
            store.selectNext()
            return true
        }
        if event.keyCode == 126 || event.keyCode == 123 {
            store.selectPrevious()
            return true
        }

        if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "f" {
            store.focusSearch()
            return true
        }

        if flags == .command, event.keyCode == 51 {
            if let item = store.selectedItem {
                store.delete(item)
            }
            return true
        }

        if searchFieldFocused {
            return false
        }

        if flags.isEmpty || flags == .shift, let text = event.characters, !text.isEmpty, text.unicodeScalars.allSatisfy({ !CharacterSet.newlines.contains($0) && !CharacterSet.controlCharacters.contains($0) }) {
            store.searchQuery += text
            store.focusSearch()
            store.selectFirst()
            return true
        }

        return false
    }

    private func commandNumber(from event: NSEvent) -> Int? {
        switch event.keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        default: return nil
        }
    }
}
