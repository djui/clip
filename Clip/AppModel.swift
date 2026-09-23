import AppKit

@MainActor
final class AppModel {
    static let shared = AppModel()

    let settings = AppSettings()
    let store = ClipboardStore()
    let monitor: ClipboardMonitor
    let hold = HoldPasteMonitor()
    let history = HistoryPanelController()
    let openHotkey = GlobalHotkey(id: 1)
    let plainPasteHotkey = GlobalHotkey(id: 2)
    let statusItem = StatusItemController()

    private var started = false

    private init() {
        monitor = ClipboardMonitor(store: store, settings: settings)
    }

    func start() {
        guard !started else { return }
        started = true
        let firstLaunch = settings.applyFirstLaunchDefaults()
        store.load()
        monitor.start()
        hold.holdEnabled = settings.holdCommandV
        hold.start()
        registerHotkeys()
        statusItem.install(settings: settings)
        if firstLaunch {
            PermissionOnboardingController.shared.show()
        }
    }

    func applyHoldCommandV() {
        guard started else { return }
        hold.holdEnabled = settings.holdCommandV
        if settings.holdCommandV {
            hold.start()
        } else {
            hold.stop()
        }
    }

    func registerHotkeys() {
        let open = settings.openShortcut
        if open.isValidGlobal {
            openHotkey.register(keyCode: open.keyCode, modifiers: open.carbonModifiers) { [weak self] in
                self?.history.toggle()
            }
        } else {
            openHotkey.unregister()
        }

        let plain = settings.plainPasteShortcut
        if plain.isValidGlobal {
            plainPasteHotkey.register(keyCode: plain.keyCode, modifiers: plain.carbonModifiers) { [weak self] in
                self?.pasteSelectedAsPlainText()
            }
        } else {
            plainPasteHotkey.unregister()
        }
        statusItem.refreshMenu()
    }

    func pasteSelectedAsPlainText() {
        if history.isVisible {
            history.pasteSelected(plainText: true)
        } else if let item = store.selectedItem ?? store.filteredItems.first {
            let app = NSWorkspace.shared.frontmostApplication
            PasteService.paste(item, plainText: true, into: app)
        }
    }

    func stop() {
        openHotkey.unregister()
        plainPasteHotkey.unregister()
        monitor.stop()
        hold.stop()
        history.hide()
    }
}
