import AppKit
import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    @Environment(ClipboardStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let name = item.sourceAppName {
                        Text(name)
                            .lineLimit(1)
                    }
                    Text(item.createdAt, formatter: Self.relativeFormatter)
                    if index < 9 {
                        Text("⌘\(index + 1)")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Button {
                store.togglePin(item)
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.isPinned ? Color.yellow : Color.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin" : "Pin")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            AppModel.shared.history.paste(
                item,
                plainText: flags.contains(.shift) || flags.contains(.option)
            )
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.kind == .color {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: NSColor(hex: item.colorHex ?? "") ?? .gray))
                .frame(width: 36, height: 36)
        } else if let image = item.previewImage, item.kind == .image || item.kind == .file {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
