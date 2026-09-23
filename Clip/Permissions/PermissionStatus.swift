import AppKit
import ApplicationServices
import Foundation

enum PermissionState: Equatable {
    case granted
    case denied
    case notDetermined
    case unavailable
}

enum PermissionStatus {
    static var isAccessibilityTrusted: Bool {
        PasteService.isTrusted
    }

    static func requestAccessibility() {
        PasteService.requestTrust()
    }

    static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for string in candidates {
            if let url = URL(string: string) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}

@Observable
@MainActor
final class PermissionCenter {
    var accessibilityTrusted = PasteService.isTrusted

    func refresh() {
        accessibilityTrusted = PasteService.isTrusted
        AppModel.shared.hold.start()
    }

    func requestAccessibility() {
        PermissionStatus.requestAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }
}
