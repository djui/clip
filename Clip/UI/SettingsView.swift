import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsForm()
            .frame(width: 520, height: 620)
            .navigationTitle("Clip Settings")
    }
}

private struct SettingsForm: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ClipboardStore.self) private var store
    @State private var center = PermissionCenter()

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if settings.loginItemBlocked {
                    Text("macOS is waiting for approval. Enable Clip in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items") {
                        settings.openLoginItemsSettings()
                    }
                }
                Toggle("Show menu bar icon", isOn: Bindable(settings).showStatusItem)
                Toggle("Show history when holding ⌘V", isOn: Bindable(settings).holdCommandV)
                Text("A quick ⌘V still pastes. Hold it to open history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Also open with")
                    Spacer()
                    HotkeyRecorder(
                        shortcut: Bindable(settings).openShortcut,
                        defaultShortcut: .unset,
                        allowsNone: true
                    )
                }
            }

            Section("History") {
                Toggle("Pause clipboard capture", isOn: Bindable(settings).isPaused)
                Toggle("Show content previews", isOn: Bindable(settings).showContentPreviews)
                Text("Show thumbnails for images, PDFs, and other media. Text items keep a type icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Compact rows", isOn: Bindable(settings).compactListRows)
                Text("Show each item on a single line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: Bindable(settings).historyLimit, in: 20...2000, step: 20) {
                    Text("Keep \(settings.historyLimit) items")
                }
                Text("Pinned items are kept even when the limit is reached.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear Clipboard History", role: .destructive) {
                    store.confirmAndClearHistory()
                }
                .disabled(store.unpinnedCount == 0)
                HStack {
                    Text("Paste as Plain Text")
                    Spacer()
                    HotkeyRecorder(
                        shortcut: Bindable(settings).plainPasteShortcut,
                        defaultShortcut: .defaultPlainPaste,
                        allowShiftOnly: true
                    )
                }
            }

            Section("Paste") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                        Text("Required to paste and to watch ⌘V.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if center.accessibilityTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Not granted")
                            .foregroundStyle(.orange)
                    }
                }
                if !center.accessibilityTrusted {
                    Text("macOS grants Accessibility per app copy. Xcode Debug and a released Clip.app are different binaries. Enable the entry that matches this build, then relaunch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Bundle.main.bundlePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                    HStack {
                        Button("Request Access") {
                            center.requestAccessibility()
                        }
                        Button("Open System Settings") {
                            PermissionStatus.openAccessibilitySettings()
                        }
                        Button("Relaunch Clip") {
                            NSApp.relaunch()
                        }
                    }
                }
            }

            Section {
                LabeledContent("Version", value: AppInfo.versionLabel)
                Button("About Clip…") {
                    AboutWindowController.shared.show()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { center.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            center.refresh()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
        )
    }
}
