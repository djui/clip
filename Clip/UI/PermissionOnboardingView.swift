import AppKit
import SwiftUI

struct PermissionOnboardingView: View {
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "clipboard.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 72, height: 72)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("Clip needs Accessibility to paste and to open history when you hold ⌘V.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Text("A quick ⌘V still pastes. Choose “Allow” when macOS asks.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button(action: continueTapped) {
                Text("Continue")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: 420, height: 320)
    }

    private func continueTapped() {
        PermissionStatus.requestAccessibility()
        onFinished()
    }
}

@MainActor
final class PermissionOnboardingController: NSObject, NSWindowDelegate {
    static let shared = PermissionOnboardingController()

    private var window: NSWindow?

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show() {
        if window == nil {
            let root = PermissionOnboardingView { [weak self] in
                self?.finish()
            }
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Clip Permissions"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.level = .normal
            window.delegate = self
            window.setContentSize(NSSize(width: 420, height: 320))
            window.center()
            self.window = window
        }
        AccessoryWindowPolicy.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func restoreKey() {
        guard isVisible else { return }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        finish(closeWindow: false)
    }

    private func finish(closeWindow: Bool = true) {
        if closeWindow {
            window?.close()
        }
        DispatchQueue.main.async {
            AccessoryWindowPolicy.refresh()
            AppModel.shared.hold.start()
        }
    }
}
