//
//  ClipboardHistoryView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

extension Notification.Name {
    static let clipboardDidSaveClip = Notification.Name("ClipboardDidSaveClip")
}

struct ClipboardHistoryView: View {
    
    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void
    let highlightedClipID: String?
    
    @State private var clips: [ClipboardItem] = []
    @State private var selectedID: String? = nil
    @State private var highlightedID: String? = nil
    @StateObject private var thumbnailStore = ClipboardThumbnailStore()
    @State private var refreshTimer: Timer? = nil
    @State private var highlightWorkItem: DispatchWorkItem? = nil

    private let appGroupDefaults = UserDefaults(suiteName: "group.com.rishimore.socialwand")
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let _ = thumbnailStore.refreshToken
        GeometryReader { geometry in
            let breakpoint = KeyboardBreakpoint.from(height: geometry.size.height)
            let metrics = ClipboardMetrics.metrics(for: breakpoint)
            
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                if clips.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        header(metrics: metrics)
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: metrics.cardSpacing) {
                                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                                        clipCard(clip: clip, metrics: metrics)
                                            .id(clip.id)
                                            .onAppear {
                                                loadThumbnailIfNeeded(for: clip, at: index)
                                            }
                                            .onDisappear {
                                                releaseThumbnailIfNeeded(for: clip)
                                            }
                                    }
                                }
                                .padding(.horizontal, metrics.horizontalPadding)
                                .padding(.top, metrics.contentTopPadding)
                                .padding(.bottom, metrics.bottomPadding)
                            }
                            .onAppear {
                                scrollToHighlighted(proxy)
                            }
                            .onChange(of: highlightedID) { _, _ in
                                scrollToHighlighted(proxy)
                            }
                            .onChange(of: clips.map(\.id)) { _, _ in
                                scrollToHighlighted(proxy)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadClips()
            CloudClipboardSyncService.shared.setFetchMode(active: true)
            refreshFromCloud()
            startRefreshTimer()
            if let highlightedClipID {
                highlightClip(id: highlightedClipID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: CloudClipboardSyncService.didSyncNotification)) { _ in
            loadClips()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: appGroupDefaults)) { _ in
            loadClips()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardDidSaveClip)) { notification in
            if let clipID = notification.userInfo?["clipID"] as? String {
                highlightClip(id: clipID)
            }
        }
        .onDisappear {
            thumbnailStore.clear()
            CloudClipboardSyncService.shared.setFetchMode(active: false)
            stopRefreshTimer()
            highlightWorkItem?.cancel()
            highlightWorkItem = nil
        }
    }
    
    // MARK: - Header
    
    private func header(metrics: ClipboardMetrics) -> some View {
        HStack(spacing: 8) {
            Text("Clipboard")
                .font(.system(size: metrics.headerFont, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "8B5CF6"))
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    // MARK: - Clip Card
    
    private func clipCard(clip: ClipboardItem, metrics: ClipboardMetrics) -> some View {
        let isSelected = selectedID == clip.id
        let isHighlighted = highlightedID == clip.id && !isSelected
        
        return ZStack {
            // Main card button (for tap to select)
            Button(action: { toggleSelection(for: clip.id) }) {
                // Content section
                VStack(alignment: .leading, spacing: 10) {
                    if clip.type == .text, let text = clip.textContent {
                        Text(text)
                            .font(.system(size: metrics.titleFont))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if clip.type == .image {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                // Lazy-loaded thumbnail
                                if let thumbFilename = clip.thumbnailFilename,
                                   let thumbnail = thumbnailStore.image(for: thumbFilename) {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                } else {
                                    // Placeholder while loading
                                    Image(systemName: "photo")
                                        .font(.system(size: metrics.titleFont, weight: .semibold))
                                        .frame(width: 48, height: 48)
                                        .background(Color.gray.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                
                                Text("Image")
                                    .font(.system(size: metrics.titleFont, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            // Clear instructions for images
                            HStack(spacing: 4) {
                                Text("💡")
                                    .font(.system(size: 12))
                                Text("Tap to copy → Paste in text field")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .blur(radius: isSelected ? 2 : 0)  // ✅ NEW: Blur content when selected
                .animation(.easeInOut(duration: 0.2), value: isSelected)  // ✅ NEW: Smooth blur transition
                .padding(.horizontal, metrics.cardHorizontalPadding)
                .padding(.vertical, metrics.cardVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        cardBackground
                        if isHighlighted {
                            Color(hex: "8B5CF6").opacity(0.12)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.cornerRadius)
                        .stroke(
                            isSelected ? Color(hex: "8B5CF6") : (isHighlighted ? Color(hex: "8B5CF6").opacity(0.7) : Color.gray.opacity(0.3)),
                            lineWidth: isSelected ? metrics.borderWidth : 1.5
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
                .shadow(color: isSelected ? Color(hex: "8B5CF6").opacity(0.15) : .clear, radius: 8, y: 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Bookmark icon (top-right, always visible)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { toggleBookmark(clip) }) {
                        bookmarkIcon(isOn: clip.isBookmarked)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
                Spacer()
            }
            .allowsHitTesting(true)
            
            // Overlay buttons (centered, only when selected)
            if isSelected {
                HStack(spacing: 12) {
                    // Apply/Copy button (text shows "Apply" for text clips, "Copy" for image clips)
                    Button(action: { pasteClip(clip) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text(clip.type == .image ? "Copy" : "Apply")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                // Blur background
                                BlurView(style: colorScheme == .dark ? .dark : .light)
                                
                                // Purple gradient overlay
                                LinearGradient(
                                    colors: [
                                        Color(hex: "8B5CF6").opacity(0.9),
                                        Color(hex: "7C3AED").opacity(0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    
                    // Trash icon button
                    Button(action: { deleteClip(clip) }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(true)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
    
    @ViewBuilder
    private func bookmarkIcon(isOn: Bool) -> some View {
        if isOn {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(Color(hex: "8B5CF6"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: "bookmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No saved clips")
                .font(.system(size: 20, weight: .bold))
            
            Text("Tap 'Save to Clipboard' to save items")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
    }
    
    // MARK: - Actions
    
    private func loadClips() {
        clips = ClipboardManager.shared.retrieveClips()
        print("📋 Loaded \(clips.count) clips metadata")
    }

    private func refreshFromCloud() {
        CloudClipboardSyncService.shared.checkSyncAvailability(requiresOpenAccess: true) { availability in
            guard availability == .available else { return }
            CloudClipboardSyncService.shared.fetchRemoteChanges()
        }
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            refreshFromCloud()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func loadThumbnailIfNeeded(for clip: ClipboardItem) {
        loadThumbnailIfNeeded(for: clip, at: nil)
    }

    private func loadThumbnailIfNeeded(for clip: ClipboardItem, at index: Int?) {
        guard clip.type == .image,
              let thumbFilename = clip.thumbnailFilename else { return }

        thumbnailStore.loadIfNeeded(filename: thumbFilename) {
            ClipboardManager.shared.loadThumbnail(filename: thumbFilename)
        }

        guard let index else { return }
        prefetchThumbnails(startingAt: index + 1, count: 2)
    }

    private func prefetchThumbnails(startingAt index: Int, count: Int) {
        guard index < clips.count else { return }
        let end = min(index + count, clips.count)
        for clip in clips[index..<end] where clip.type == .image {
            guard let thumbFilename = clip.thumbnailFilename else { continue }
            thumbnailStore.loadIfNeeded(filename: thumbFilename) {
                ClipboardManager.shared.loadThumbnail(filename: thumbFilename)
            }
        }
    }

    private func releaseThumbnailIfNeeded(for clip: ClipboardItem) {
        guard clip.type == .image,
              let thumbFilename = clip.thumbnailFilename else { return }
        thumbnailStore.remove(filename: thumbFilename)
    }
    
    private func toggleSelection(for id: String) {
        if selectedID == id {
            // Deselecting
            selectedID = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            // Selecting
            selectedID = id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func highlightClip(id: String) {
        highlightedID = id
        highlightWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                if highlightedID == id {
                    highlightedID = nil
                }
            }
        }
        highlightWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func scrollToHighlighted(_ proxy: ScrollViewProxy) {
        guard let id = highlightedID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
    
    private func pasteClip(_ clip: ClipboardItem) {
        onPaste(clip)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func deleteClip(_ clip: ClipboardItem) {
        _ = ClipboardManager.shared.deleteClip(clipID: clip.id)
        selectedID = nil
        loadClips()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func toggleBookmark(_ clip: ClipboardItem) {
        _ = ClipboardManager.shared.toggleBookmark(clipID: clip.id)
        loadClips()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Colors
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : .white
    }
}

// MARK: - Breakpoint

private enum KeyboardBreakpoint {
    case small
    case medium
    case large
    
    static func from(height: CGFloat) -> KeyboardBreakpoint {
        if height < 250 { return .small }
        if height < 350 { return .medium }
        return .large
    }
}

// MARK: - Metrics

private struct ClipboardMetrics {
    let horizontalPadding: CGFloat
    let contentTopPadding: CGFloat
    let cardSpacing: CGFloat
    let cardHorizontalPadding: CGFloat
    let cardVerticalPadding: CGFloat
    let headerFont: CGFloat
    let titleFont: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let bottomPadding: CGFloat
    let buttonWidth: CGFloat
    let buttonHeight: CGFloat
    let buttonSpacing: CGFloat
    
    static func metrics(for breakpoint: KeyboardBreakpoint) -> ClipboardMetrics {
        switch breakpoint {
        case .small:
            return ClipboardMetrics(
                horizontalPadding: 16, contentTopPadding: 8, cardSpacing: 10,
                cardHorizontalPadding: 14, cardVerticalPadding: 12,
                headerFont: 18, titleFont: 16, cornerRadius: 16, borderWidth: 3,
                bottomPadding: 120, buttonWidth: 100, buttonHeight: 46, buttonSpacing: 12
            )
        case .medium:
            return ClipboardMetrics(
                horizontalPadding: 18, contentTopPadding: 12, cardSpacing: 12,
                cardHorizontalPadding: 16, cardVerticalPadding: 14,
                headerFont: 20, titleFont: 17, cornerRadius: 18, borderWidth: 3,
                bottomPadding: 120, buttonWidth: 110, buttonHeight: 46, buttonSpacing: 12
            )
        case .large:
            return ClipboardMetrics(
                horizontalPadding: 20, contentTopPadding: 16, cardSpacing: 14,
                cardHorizontalPadding: 18, cardVerticalPadding: 16,
                headerFont: 22, titleFont: 18, cornerRadius: 20, borderWidth: 3,
                bottomPadding: 120, buttonWidth: 120, buttonHeight: 46, buttonSpacing: 12
            )
        }
    }
}

final class ClipboardThumbnailStore: ObservableObject {
    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var inFlight = Set<String>()
    @Published private(set) var refreshToken = UUID()

    init() {
        cache.countLimit = 8
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func image(for filename: String) -> UIImage? {
        cache.object(forKey: filename as NSString)
    }

    func loadIfNeeded(filename: String, loader: @escaping () -> UIImage?) {
        if cache.object(forKey: filename as NSString) != nil {
            return
        }
        lock.lock()
        if inFlight.contains(filename) {
            lock.unlock()
            return
        }
        inFlight.insert(filename)
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = loader()
            DispatchQueue.main.async {
                guard let self else { return }
                self.lock.lock()
                self.inFlight.remove(filename)
                self.lock.unlock()
                if let image {
                    self.cache.setObject(image, forKey: filename as NSString)
                    self.refreshToken = UUID()
                }
            }
        }
    }

    func remove(filename: String) {
        cache.removeObject(forKey: filename as NSString)
    }

    func clear() {
        cache.removeAllObjects()
        refreshToken = UUID()
    }

    @objc private func handleMemoryWarning() {
        clear()
    }
}

// MARK: - Button Style

private struct CornerButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
