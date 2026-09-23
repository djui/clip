import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private var settings: AppSettings?

    func install(settings: AppSettings) {
        self.settings = settings
        applyVisibility()
    }

    func applyVisibility() {
        let visible = settings?.showStatusItem ?? true
        if visible {
            if item == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = item.button {
                    button.image = MenuBarIcon.image()
                    button.imagePosition = .imageOnly
                    button.toolTip = "Clip"
                }
                let menu = NSMenu()
                menu.delegate = self
                item.menu = menu
                self.item = item
            }
            item?.isVisible = true
        } else {
            item?.isVisible = false
        }
    }

    func refreshMenu() {
        if let menu = item?.menu {
            menuNeedsUpdate(menu)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let shortcut = settings?.openShortcut ?? .unset
        let open = menu.addItem(withTitle: "Open Clip", action: #selector(openClip), keyEquivalent: shortcut.menuKeyEquivalent)
        if shortcut.isValidGlobal {
            open.keyEquivalentModifierMask = shortcut.nsEventModifiers
        }
        open.target = self

        let paused = settings?.isPaused == true
        let pause = menu.addItem(
            withTitle: paused ? "Resume Capture" : "Pause Capture",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pause.target = self

        let clear = menu.addItem(
            withTitle: "Clear Clipboard History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clear.target = self
        clear.isEnabled = AppModel.shared.store.unpinnedCount > 0

        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        let hide = menu.addItem(withTitle: "Hide Menu Bar Icon", action: #selector(hideStatusItem), keyEquivalent: "")
        hide.target = self

        menu.addItem(.separator())
        let about = menu.addItem(withTitle: "About Clip", action: #selector(openAbout), keyEquivalent: "")
        about.target = self

        let quit = menu.addItem(withTitle: "Quit Clip", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
    }

    @objc private func openClip() {
        AppModel.shared.history.toggle()
    }

    @objc private func togglePause() {
        settings?.isPaused.toggle()
    }

    @objc private func clearHistory() {
        AppModel.shared.store.confirmAndClearHistory()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openAbout() {
        AboutWindowController.shared.show()
    }

    @objc private func hideStatusItem() {
        settings?.showStatusItem = false
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
