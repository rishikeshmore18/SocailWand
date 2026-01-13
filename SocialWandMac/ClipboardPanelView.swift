import SwiftUI

final class ClipboardPanelViewModel: ObservableObject {
    @Published var clips: [MacClipboardItem] = []

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardUpdate),
            name: MacClipboardSyncService.didUpdateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: MacClipboardSyncService.didUpdateNotification,
            object: nil
        )
    }

    func refresh() {
        MacClipboardSyncService.shared.fetchClips { [weak self] clips in
            self?.clips = clips
        }
    }

    @objc private func handleClipboardUpdate() {
        refresh()
    }
}

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    let onSelect: (MacClipboardItem) -> Void
    let onDelete: (MacClipboardItem) -> Void
    let onToggleBookmark: (MacClipboardItem) -> Void
    let showSaveButton: Bool
    let onSave: (() -> Void)?
    let onClose: (() -> Void)?

    init(
        viewModel: ClipboardPanelViewModel,
        onSelect: @escaping (MacClipboardItem) -> Void,
        onDelete: @escaping (MacClipboardItem) -> Void,
        onToggleBookmark: @escaping (MacClipboardItem) -> Void,
        showSaveButton: Bool = false,
        onSave: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onToggleBookmark = onToggleBookmark
        self.showSaveButton = showSaveButton
        self.onSave = onSave
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Clipboard")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if let onClose {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if showSaveButton, let onSave {
                Button {
                    onSave()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Save to Clipboard")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.clips) { clip in
                        Button {
                            onSelect(clip)
                        } label: {
                            ClipRowView(clip: clip)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button("Apply") {
                                onSelect(clip)
                            }
                            Button(clip.isBookmarked ? "Remove Bookmark" : "Bookmark") {
                                onToggleBookmark(clip)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                onDelete(clip)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
    }
}

private struct ClipRowView: View {
    let clip: MacClipboardItem

    var body: some View {
        HStack(spacing: 12) {
            if let image = clip.displayImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text(clip.displayText)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.white)
            }

            if clip.isBookmarked {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
