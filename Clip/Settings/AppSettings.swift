import Foundation
import ServiceManagement
import SwiftUI

@Observable
@MainActor
final class AppSettings {
    private enum Keys {
        static let didCompleteFirstLaunch = "didCompleteFirstLaunch"
        static let isPaused = "isPaused"
        static let historyLimit = "historyLimit"
        static let ignoredBundleIDs = "ignoredBundleIDs"
        static let showStatusItem = "showStatusItem"
        static let holdCommandV = "holdCommandV"
        static let showContentPreviews = "showContentPreviews"
        static let compactListRows = "compactListRows"
        static let openHotkeyKeyCode = "openHotkeyKeyCode"
        static let openHotkeyModifiers = "openHotkeyModifiers"
        static let plainHotkeyKeyCode = "plainHotkeyKeyCode"
        static let plainHotkeyModifiers = "plainHotkeyModifiers"
    }

    var isPaused: Bool {
        didSet { UserDefaults.standard.set(isPaused, forKey: Keys.isPaused) }
    }

    var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: Keys.historyLimit) }
    }

    var ignoredBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(ignoredBundleIDs), forKey: Keys.ignoredBundleIDs)
        }
    }

    var showStatusItem: Bool {
        didSet {
            UserDefaults.standard.set(showStatusItem, forKey: Keys.showStatusItem)
            AppModel.shared.statusItem.applyVisibility()
        }
    }

    var holdCommandV: Bool {
        didSet {
            UserDefaults.standard.set(holdCommandV, forKey: Keys.holdCommandV)
            AppModel.shared.applyHoldCommandV()
        }
    }

    var showContentPreviews: Bool {
        didSet { UserDefaults.standard.set(showContentPreviews, forKey: Keys.showContentPreviews) }
    }

    var compactListRows: Bool {
        didSet { UserDefaults.standard.set(compactListRows, forKey: Keys.compactListRows) }
    }

    var openShortcut: KeyboardShortcut {
        didSet {
            if openShortcut.isSet {
                UserDefaults.standard.set(Int(openShortcut.keyCode), forKey: Keys.openHotkeyKeyCode)
                UserDefaults.standard.set(Int(openShortcut.carbonModifiers), forKey: Keys.openHotkeyModifiers)
            } else {
                UserDefaults.standard.set(-1, forKey: Keys.openHotkeyKeyCode)
                UserDefaults.standard.set(0, forKey: Keys.openHotkeyModifiers)
            }
            AppModel.shared.registerHotkeys()
        }
    }

    var plainPasteShortcut: KeyboardShortcut {
        didSet {
            UserDefaults.standard.set(Int(plainPasteShortcut.keyCode), forKey: Keys.plainHotkeyKeyCode)
            UserDefaults.standard.set(Int(plainPasteShortcut.carbonModifiers), forKey: Keys.plainHotkeyModifiers)
            AppModel.shared.registerHotkeys()
        }
    }

    var launchAtLogin: Bool

    var loginItemBlocked: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    init() {
        isPaused = UserDefaults.standard.bool(forKey: Keys.isPaused)
        let storedLimit = UserDefaults.standard.integer(forKey: Keys.historyLimit)
        historyLimit = storedLimit > 0 ? storedLimit : 500
        let ignored = UserDefaults.standard.stringArray(forKey: Keys.ignoredBundleIDs) ?? []
        ignoredBundleIDs = Set(ignored)
        if UserDefaults.standard.object(forKey: Keys.showStatusItem) == nil {
            showStatusItem = true
        } else {
            showStatusItem = UserDefaults.standard.bool(forKey: Keys.showStatusItem)
        }
        if UserDefaults.standard.object(forKey: Keys.holdCommandV) == nil {
            holdCommandV = true
        } else {
            holdCommandV = UserDefaults.standard.bool(forKey: Keys.holdCommandV)
        }
        if UserDefaults.standard.object(forKey: Keys.showContentPreviews) == nil {
            showContentPreviews = true
        } else {
            showContentPreviews = UserDefaults.standard.bool(forKey: Keys.showContentPreviews)
        }
        if UserDefaults.standard.object(forKey: Keys.compactListRows) == nil {
            compactListRows = false
        } else {
            compactListRows = UserDefaults.standard.bool(forKey: Keys.compactListRows)
        }
        openShortcut = Self.loadOptionalShortcut(
            keyCodeKey: Keys.openHotkeyKeyCode,
            modifiersKey: Keys.openHotkeyModifiers
        )
        plainPasteShortcut = Self.loadShortcut(
            keyCodeKey: Keys.plainHotkeyKeyCode,
            modifiersKey: Keys.plainHotkeyModifiers,
            fallback: .defaultPlainPaste,
            requireGlobal: false
        )
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private static func loadOptionalShortcut(keyCodeKey: String, modifiersKey: String) -> KeyboardShortcut {
        guard UserDefaults.standard.object(forKey: keyCodeKey) != nil else { return .unset }
        let storedCode = UserDefaults.standard.integer(forKey: keyCodeKey)
        guard storedCode >= 0 else { return .unset }
        let stored = KeyboardShortcut(
            keyCode: UInt32(storedCode),
            carbonModifiers: UInt32(UserDefaults.standard.integer(forKey: modifiersKey))
        )
        return stored.isValidGlobal ? stored : .unset
    }

    private static func loadShortcut(
        keyCodeKey: String,
        modifiersKey: String,
        fallback: KeyboardShortcut,
        requireGlobal: Bool
    ) -> KeyboardShortcut {
        guard UserDefaults.standard.object(forKey: keyCodeKey) != nil else { return fallback }
        let stored = KeyboardShortcut(
            keyCode: UInt32(UserDefaults.standard.integer(forKey: keyCodeKey)),
            carbonModifiers: UInt32(UserDefaults.standard.integer(forKey: modifiersKey))
        )
        if requireGlobal {
            return stored.isValidGlobal ? stored : fallback
        }
        return stored.isValidLocal ? stored : fallback
    }

    @discardableResult
    func applyFirstLaunchDefaults() -> Bool {
        if !UserDefaults.standard.bool(forKey: Keys.didCompleteFirstLaunch) {
            UserDefaults.standard.set(true, forKey: Keys.didCompleteFirstLaunch)
            setLaunchAtLogin(true)
            return true
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        return false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    launchAtLogin = true
                    return
                }
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Clip: launch at login failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
