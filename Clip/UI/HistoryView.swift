import SwiftUI

struct HistoryView: View {
    @Environment(ClipboardStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.filteredItems.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(width: 440, height: 520)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: store.searchFocusGeneration) { _, _ in
            searchFocused = true
        }
        .onChange(of: searchFocused) { _, focused in
            AppModel.shared.history.searchFieldFocused = focused
        }
        .onChange(of: store.searchQuery) { _, _ in
            store.selectFirst()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search", text: Bindable(store).searchQuery)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(.system(size: 13, weight: .medium))
            Text(settings.isPaused ? "Paused" : "\(store.filteredItems.count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Button {
                settings.isPaused.toggle()
            } label: {
                Image(systemName: settings.isPaused ? "pause.circle.fill" : "pause.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(settings.isPaused ? "Resume capture" : "Pause capture")
            Button {
                AppModel.shared.history.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(store.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipRowView(
                            item: item,
                            index: index,
                            selected: item.id == store.selectedItem?.id
                        )
                        .id(item.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: store.scrollGeneration) { _, _ in
                if let id = store.selectedItem?.id {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.searchQuery.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
            Text(store.searchQuery.isEmpty ? "Copy something to get started" : "No matches")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        Text("↩ paste   ·   ⌘1–9   ·   ⌘⌫ delete")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
    }
}
