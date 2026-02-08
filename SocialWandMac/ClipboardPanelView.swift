import SwiftUI

final class ClipboardPanelViewModel: ObservableObject {
    @Published var clips: [MacClipboardItem] = []
    @Published var cloudStatusMessage: String?
    private var refreshTimer: Timer?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardUpdate),
            name: MacClipboardSyncService.didUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudStatusUpdate(_:)),
            name: MacClipboardSyncService.cloudStatusDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: MacClipboardSyncService.didUpdateNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: MacClipboardSyncService.cloudStatusDidChangeNotification,
            object: nil
        )
    }

    func refresh() {
        MacClipboardSyncService.shared.fetchClips { [weak self] clips in
            guard let self else { return }
            if self.clips != clips {
                self.clips = clips
            }
        }
    }

    func startPolling() {
        guard refreshTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func handleClipboardUpdate() {
        refresh()
    }

    @objc private func handleCloudStatusUpdate(_ notification: Notification) {
        let message = notification.userInfo?["message"] as? String
        cloudStatusMessage = message
    }
}

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    let onSelect: (MacClipboardItem) -> Void
    let onDelete: (MacClipboardItem) -> Void
    let onToggleBookmark: (MacClipboardItem) -> Void
    let showSaveButton: Bool
    let autoSaveEnabled: Bool
    let onSave: (() -> Void)?
    let onClose: (() -> Void)?

    init(
        viewModel: ClipboardPanelViewModel,
        onSelect: @escaping (MacClipboardItem) -> Void,
        onDelete: @escaping (MacClipboardItem) -> Void,
        onToggleBookmark: @escaping (MacClipboardItem) -> Void,
        showSaveButton: Bool = false,
        autoSaveEnabled: Bool = true,
        onSave: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onToggleBookmark = onToggleBookmark
        self.showSaveButton = showSaveButton
        self.autoSaveEnabled = autoSaveEnabled
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
                HStack(spacing: 10) {
                    Button {
                        onSave()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Save to Clipboard")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Text(autoSaveEnabled ? "Auto‑save: On" : "Auto‑save: Off")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }

            // ✅ Static status row - always visible to prevent layout shifts
            HStack {
                if let message = viewModel.cloudStatusMessage, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    // Invisible placeholder to maintain consistent height
                    Text(" ")
                        .font(.caption)
                        .foregroundColor(.clear)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(height: 24) // Fixed height to prevent layout shifts
            .background(
                Group {
                    if let message = viewModel.cloudStatusMessage, !message.isEmpty {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.clear)
                    }
                }
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.clips) { clip in
                        ClipRowView(
                            clip: clip,
                            onSelect: { onSelect(clip) },
                            onToggleBookmark: { onToggleBookmark(clip) },
                            onDelete: { onDelete(clip) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(clip)
                        }
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
        )
        .onAppear {
            MacClipboardSyncService.shared.setFetchMode(active: true)
            viewModel.refresh()
            viewModel.startPolling()
        }
        .onDisappear {
            MacClipboardSyncService.shared.setFetchMode(active: false)
            viewModel.stopPolling()
        }
    }
}

private struct ClipRowView: View {
    let clip: MacClipboardItem
    let onSelect: () -> Void
    let onToggleBookmark: () -> Void
    let onDelete: () -> Void

    private let highlightColor = Color(red: 0.545, green: 0.361, blue: 0.965)

    var body: some View {
        HStack(spacing: 12) {
            // Main content area
            Group {
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
            }
            
            Spacer()
            
            // ✅ Icons inside the clip - Vertical column on the right with blur backgrounds
            VStack(spacing: 6) {
                // Bookmark icon - Top right
                Button(action: onToggleBookmark) {
                    Image(systemName: clip.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(clip.isBookmarked ? highlightColor : .white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())

                // Three dots menu - Bottom right
                Menu {
                    Button("Apply") {
                        onSelect()
                    }
                    Button(clip.isBookmarked ? "Remove Bookmark" : "Bookmark") {
                        onToggleBookmark()
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .menuStyle(BorderlessButtonMenuStyle())
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
