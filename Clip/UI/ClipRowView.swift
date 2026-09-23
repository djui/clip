import AppKit
import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    @Environment(ClipboardStore.self) private var store
    @Environment(AppSettings.self) private var settings

    private var compact: Bool { settings.compactListRows }
    private var thumbSize: CGFloat { compact ? 24 : 36 }

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            thumbnail
            if compact {
                compactContent
            } else {
                standardContent
            }
            Spacer(minLength: 4)
            if compact, index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(.tertiary)
            }
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
        .padding(.vertical, compact ? 4 : 6)
        .background {
            RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
        .onTapGesture {
            let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            AppModel.shared.history.paste(
                item,
                plainText: flags.contains(.shift) || flags.contains(.option)
            )
        }
    }

    private var compactContent: some View {
        Text(item.previewText)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var standardContent: some View {
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
    }

    @ViewBuilder
    private var thumbnail: some View {
        if settings.showContentPreviews, item.hasMediaPreview {
            mediaPreview
        } else {
            typeIcon
        }
    }

    @ViewBuilder
    private var mediaPreview: some View {
        if item.kind == .color {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: NSColor(hex: item.colorHex ?? "") ?? .gray))
                .frame(width: thumbSize, height: thumbSize)
        } else if let image = item.listThumbnail(pixelSize: thumbSize * 2) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            typeIcon
        }
    }

    private var typeIcon: some View {
        Image(systemName: item.kind.symbolName)
            .font(.system(size: compact ? 11 : 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: thumbSize, height: thumbSize)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
