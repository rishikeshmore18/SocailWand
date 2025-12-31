//
//  ClipboardHistoryView.swift
//  SocialWandKeyboard
//

import SwiftUI

struct ClipboardHistoryView: View {
    
    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void
    
    @State private var clips: [ClipboardItem] = []
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            if clips.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        headerView
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                        
                        // Bookmarked section
                        if !bookmarkedClips.isEmpty {
                            sectionHeader(title: "⭐ Bookmarked", count: bookmarkedClips.count)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            
                            ForEach(bookmarkedClips) { clip in
                                clipCard(clip: clip)
                            }
                        }
                        
                        // Regular clips section
                        if !regularClips.isEmpty {
                            sectionHeader(title: "📋 Recent", count: regularClips.count)
                                .padding(.horizontal, 16)
                                .padding(.top, bookmarkedClips.isEmpty ? 8 : 16)
                            
                            ForEach(regularClips) { clip in
                                clipCard(clip: clip)
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .onAppear {
            loadClips()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard")
                    .font(.system(size: 18, weight: .bold))
                Text("\(clips.count) saved items")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "8B5CF6"))
            }
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Text("(\(count))")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
    }
    
    // MARK: - Clip Card
    
    private func clipCard(clip: ClipboardItem) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Text content (max 2 lines)
                Text(clip.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
                
                // Paste button (overlaid on bottom)
                HStack {
                    Spacer()
                    Button(action: { handlePaste(clip) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 13))
                            Text("Paste")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                // Blur background
                                Color.black.opacity(0.3)
                                    .blur(radius: 8)
                                
                                // Gradient overlay
                                LinearGradient(
                                    colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        )
                        .cornerRadius(16)
                    }
                }
                .offset(y: -8)
            }
            .padding(16)
            .background(cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
            // Bookmark icon (top right)
            Button(action: { toggleBookmark(clip) }) {
                Image(systemName: clip.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(clip.isBookmarked ? Color(hex: "8B5CF6") : .gray)
                    .padding(12)
            }
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
            
            Text("Tap 'Save' to save items")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
    }
    
    // MARK: - Helpers
    
    private var bookmarkedClips: [ClipboardItem] {
        clips.filter { $0.isBookmarked }
    }
    
    private var regularClips: [ClipboardItem] {
        clips.filter { !$0.isBookmarked }
    }
    
    private func loadClips() {
        clips = ClipboardManager.shared.retrieveClips()
    }
    
    private func handlePaste(_ clip: ClipboardItem) {
        onPaste(clip)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func toggleBookmark(_ clip: ClipboardItem) {
        _ = ClipboardManager.shared.toggleBookmark(clipID: clip.id)
        loadClips()
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - Colors
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : .white
    }
}

