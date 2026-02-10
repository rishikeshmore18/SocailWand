//
//  ClipboardHistoryView.swift
//  social wand
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
    @State private var loadedThumbnails: [String: UIImage] = [:]
    @State private var refreshTimer: Timer? = nil
    @State private var highlightWorkItem: DispatchWorkItem? = nil

    private let appGroupDefaults = UserDefaults(suiteName: "group.com.rishimore.socialwand")
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
                                    ForEach(clips) { clip in
                                        clipCard(clip: clip, metrics: metrics)
                                            .id(clip.id)
                                            .onAppear {
                                                loadThumbnailIfNeeded(for: clip)
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
            // Clear thumbnails from RAM when view closes
            loadedThumbnails.removeAll()
            CloudClipboardSyncService.shared.setFetchMode(active: false)
            stopRefreshTimer()
            highlightWorkItem?.cancel()
            highlightWorkItem = nil
            print("🧹 Cleared \(loadedThumbnails.count) thumbnails from RAM")
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
        .background(backgroundColor)
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
                                   let thumbnail = loadedThumbnails[thumbFilename] {
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
            
            // Bookmark (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { toggleBookmark(clip) }) {
                        floatingIcon(
                            systemName: clip.isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                
                Spacer()
            }
            .allowsHitTesting(true)
            
            // Selection overlay with actions
            if isSelected {
                selectionOverlay(clip: clip, metrics: metrics)
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(UIColor.systemBackground))
    }
    
    private func floatingIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Color(hex: "8B5CF6"))
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
    }
    
    private func selectionOverlay(clip: ClipboardItem, metrics: ClipboardMetrics) -> some View {
        HStack(spacing: 12) {
            Button(action: { onPaste(clip) }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(OverlayButtonStyle())
            
            Button(action: { deleteClip(clip) }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(OverlayButtonStyle(isDestructive: true))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("No saved items")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Tap 'Save to Clipboard' to save items")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for clipID: String) {
        if selectedID == clipID {
            selectedID = nil
        } else {
            selectedID = clipID
        AppHapticHelper.triggerHaptic(style: .medium)
        }
    }
    
    private func deleteClip(_ clip: ClipboardItem) {
        _ = ClipboardManager.shared.deleteClip(clipID: clip.id)
        AppHapticHelper.triggerHaptic(style: .rigid)
        selectedID = nil
        loadClips()
    }
    
    private func toggleBookmark(_ clip: ClipboardItem) {
        _ = ClipboardManager.shared.toggleBookmark(clipID: clip.id)
        AppHapticHelper.triggerHaptic(style: .light)
        loadClips()
    }
    
    private func highlightClip(id: String) {
        highlightedID = id
        
        highlightWorkItem?.cancel()
        let workItem = DispatchWorkItem { [highlightedID] in
            if highlightedID == id {
                self.highlightedID = nil
            }
        }
        highlightWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }
    
    private func loadClips() {
        clips = ClipboardManager.shared.retrieveClips()
    }
    
    private func refreshFromCloud() {
        CloudClipboardSyncService.shared.checkSyncAvailability(requiresOpenAccess: true) { availability in
            guard availability == .available else { return }
            CloudClipboardSyncService.shared.fetchRemoteChanges()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { _ in
            refreshFromCloud()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func loadThumbnailIfNeeded(for clip: ClipboardItem) {
        guard let thumbFilename = clip.thumbnailFilename else { return }
        if loadedThumbnails[thumbFilename] != nil { return }
        if let thumbnail = ClipboardManager.shared.loadThumbnail(filename: thumbFilename) {
            loadedThumbnails[thumbFilename] = thumbnail
        }
    }
    
    private func scrollToHighlighted(_ proxy: ScrollViewProxy) {
        guard let highlightedID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(highlightedID, anchor: .center)
            }
        }
    }
    
    // MARK: - Styles
    
    private var backgroundColor: Color {
        Color(UIColor.systemBackground)
    }
}

// MARK: - Styles

private struct OverlayButtonStyle: ButtonStyle {
    let isDestructive: Bool
    
    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isDestructive ? .red : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isDestructive ? 0.12 : 0.2))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

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

private struct ClipboardMetrics {
    let horizontalPadding: CGFloat
    let cardHorizontalPadding: CGFloat
    let cardVerticalPadding: CGFloat
    let cardSpacing: CGFloat
    let titleFont: CGFloat
    let headerFont: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let contentTopPadding: CGFloat
    let bottomPadding: CGFloat
    
    static func metrics(for breakpoint: KeyboardBreakpoint) -> ClipboardMetrics {
        switch breakpoint {
        case .small:
            return ClipboardMetrics(
                horizontalPadding: 12,
                cardHorizontalPadding: 12,
                cardVerticalPadding: 12,
                cardSpacing: 10,
                titleFont: 14,
                headerFont: 16,
                cornerRadius: 16,
                borderWidth: 2,
                contentTopPadding: 8,
                bottomPadding: 50
            )
        case .medium:
            return ClipboardMetrics(
                horizontalPadding: 16,
                cardHorizontalPadding: 14,
                cardVerticalPadding: 14,
                cardSpacing: 12,
                titleFont: 15,
                headerFont: 18,
                cornerRadius: 18,
                borderWidth: 2,
                contentTopPadding: 12,
                bottomPadding: 60
            )
        case .large:
            return ClipboardMetrics(
                horizontalPadding: 20,
                cardHorizontalPadding: 16,
                cardVerticalPadding: 16,
                cardSpacing: 14,
                titleFont: 16,
                headerFont: 20,
                cornerRadius: 20,
                borderWidth: 2,
                contentTopPadding: 16,
                bottomPadding: 70
            )
        }
    }
}
