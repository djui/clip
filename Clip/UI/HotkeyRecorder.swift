import AppKit
import SwiftUI

struct HotkeyRecorder: View {
    @Binding var shortcut: KeyboardShortcut
    var defaultShortcut: KeyboardShortcut
    var allowShiftOnly = false
    var allowsNone = false
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording ? cancel() : begin()
            } label: {
                Text(isRecording ? "Press shortcut…" : shortcut.display)
                    .font(.body.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isRecording ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .help("Click, then press the new shortcut")

            if allowsNone, shortcut.isSet {
                Button("Clear") {
                    cancel()
                    shortcut = .unset
                }
                .buttonStyle(.borderless)
            } else if shortcut != defaultShortcut {
                Button("Reset") {
                    cancel()
                    shortcut = defaultShortcut
                }
                .buttonStyle(.borderless)
            }
        }
        .onDisappear { cancel() }
    }

    private func begin() {
        cancel()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                cancel()
                return nil
            }
            if let next = KeyboardShortcut.from(event: event, allowShiftOnly: allowShiftOnly) {
                shortcut = next
                cancel()
            }
            return nil
        }
    }

    private func cancel() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}
