//
//  ClipboardHistoryView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

struct ClipboardHistoryView: View {
    
    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void
    
    @State private var clips: [ClipboardItem] = []
    @State private var selectedID: String? = nil
    @State private var loadedThumbnails: [String: UIImage] = [:]
    
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
                        
                        ScrollView {
                            VStack(spacing: metrics.cardSpacing) {
                                ForEach(clips) { clip in
                                    clipCard(clip: clip, metrics: metrics)
                                        .onAppear {
                                            loadThumbnailIfNeeded(for: clip)
                                        }
                                }
                            }
                            .padding(.horizontal, metrics.horizontalPadding)
                            .padding(.top, metrics.contentTopPadding)
                            .padding(.bottom, metrics.bottomPadding)
                        }
                    }
                    
                    if selectedID != nil {
                        bottomButtons(metrics: metrics)
                    }
                }
            }
        }
        .onAppear {
            loadClips()
        }
        .onDisappear {
            // Clear thumbnails from RAM when view closes
            loadedThumbnails.removeAll()
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
        .background(backgroundColor.opacity(0.95))
    }
    
    // MARK: - Clip Card
    
    private func clipCard(clip: ClipboardItem, metrics: ClipboardMetrics) -> some View {
        let isSelected = selectedID == clip.id
        
        return Button(action: { toggleSelection(for: clip.id) }) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    if clip.type == .text, let text = clip.textContent {
                        Text(text)
                            .font(.system(size: metrics.titleFont))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if clip.type == .image {
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
                            
                            Text("Image • Tap to paste")
                                .font(.system(size: metrics.titleFont))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, metrics.cardHorizontalPadding)
                .padding(.vertical, metrics.cardVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.cornerRadius)
                        .stroke(
                            isSelected ? Color(hex: "8B5CF6") : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? metrics.borderWidth : 1.5
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
                .shadow(color: isSelected ? Color(hex: "8B5CF6").opacity(0.15) : .clear, radius: 8, y: 4)
                
                // Bookmark icon
                Button(action: { toggleBookmark(clip) }) {
                    bookmarkIcon(isOn: clip.isBookmarked)
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
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
    
    // MARK: - Bottom Buttons
    
    private func bottomButtons(metrics: ClipboardMetrics) -> some View {
        VStack {
            Spacer()
            HStack(spacing: metrics.buttonSpacing) {
                Button(action: pasteSelected) {
                    Text("Paste")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: metrics.buttonWidth, height: metrics.buttonHeight)
                }
                .buttonStyle(CornerButtonStyle(color: Color(hex: "8B5CF6")))
                
                Spacer()
                
                Button(action: deleteSelected) {
                    Text("Delete")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: metrics.buttonWidth, height: metrics.buttonHeight)
                }
                .buttonStyle(CornerButtonStyle(color: Color.red))
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.bottom, 16)
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No saved clips")
                .font(.system(size: 20, weight: .bold))
            
            Text("Tap 'Paste to Wand Clipboard' to save items")
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
    
    private func loadThumbnailIfNeeded(for clip: ClipboardItem) {
        guard clip.type == .image,
              let thumbFilename = clip.thumbnailFilename,
              loadedThumbnails[thumbFilename] == nil else { return }
        
        // Lazy load thumbnail
        if let thumbnail = ClipboardManager.shared.loadThumbnail(filename: thumbFilename) {
            loadedThumbnails[thumbFilename] = thumbnail
            print("🖼️ Loaded thumbnail: \(thumbFilename)")
        }
    }
    
    private func toggleSelection(for id: String) {
        if selectedID == id {
            selectedID = nil
        } else {
            selectedID = id
        }
    }
    
    private func pasteSelected() {
        guard let id = selectedID,
              let clip = clips.first(where: { $0.id == id }) else { return }
        
        onPaste(clip)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func deleteSelected() {
        guard let id = selectedID else { return }
        
        _ = ClipboardManager.shared.deleteClip(clipID: id)
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
