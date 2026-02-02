//
//  HomeView.swift
//  social wand
//
//  Created by Cursor on 12/8/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @State private var showContent = false
    @State private var showSettings = false
    @State private var showClipboard = false
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let safeHeight = max(geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom, 1)
                let breakpoint = LayoutBreakpoint.forHeight(safeHeight)
                
                // Dynamic sizing
                let horizontalPadding = max(CGFloat(20), geo.size.width * 0.05)
                let logoSize: CGFloat = breakpoint == .veryCompact ? 50 : (breakpoint == .compact ? 56 : 60)
                let settingsIconSize: CGFloat = breakpoint == .veryCompact ? 22 : 26
                let settingsButtonSize: CGFloat = 44
                let metrics = HomeCardMetrics.metrics(for: breakpoint)
                let features = homeFeatures()
                let availableWidth = max(geo.size.width - (horizontalPadding * 2), 1)
                let gridLayout = gridLayout(
                    availableWidth: availableWidth,
                    metrics: metrics
                )
                let shouldScrollGrid = features.count > 4
                
                VStack(spacing: 0) {
                    // TOP BAR: Logo (absolute center) + Settings (absolute right)
                    ZStack {
                        // Wand Logo (absolutely centered)
                        HStack {
                            Spacer()
                            
                            Image("SocialWandLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoSize, height: logoSize)
                                .shadow(color: Color.white.opacity(0.1), radius: 12, y: 6)
                            
                            Spacer()
                        }
                        
                        // Settings button (absolute right)
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                showSettings = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: settingsButtonSize, height: settingsButtonSize)
                                    
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: settingsIconSize, weight: .medium))
                                        .foregroundStyle(AppBrand.purple)
                                }
                                .shadow(color: AppBrand.purple.opacity(0.3), radius: 8, y: 4)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .frame(height: max(logoSize, settingsButtonSize))
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)  // FIXED: Just 8pt below status bar
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
                    
                    // MAIN CONTENT AREA
                    ScrollView {
                        VStack(spacing: breakpoint == .veryCompact ? 20 : 28) {
                            // Title text
                            Text("Welcome to Social Wand")
                                .font(.system(size: breakpoint == .veryCompact ? 22 : (breakpoint == .compact ? 26 : 30), weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, breakpoint == .veryCompact ? 30 : 40)
                            
                            featureGrid(
                                features: features,
                                metrics: metrics,
                                cardSize: CGSize(width: gridLayout.cardWidth, height: gridLayout.cardHeight),
                                gridHeight: gridLayout.gridHeight,
                                shouldScroll: shouldScrollGrid,
                                horizontalPadding: horizontalPadding,
                                cardSpacing: gridLayout.cardSpacing,
                                gridInnerPadding: gridLayout.gridInnerPadding
                            )
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    }
                    
                    Spacer()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)  // Hide navigation bar completely
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showClipboard) {
                NavigationStack {
                    ClipboardHistoryView(
                        onPaste: { clip in
                            handleClipboardPaste(clip)
                        },
                        onClose: {
                            showClipboard = false
                        },
                        highlightedClipID: nil
                    )
                    .navigationTitle("Clipboard")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showClipboard = false }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettings"))) { _ in
                showSettings = true
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                    showContent = true
                }
            }
        }
    }
    
    private func homeFeatures() -> [HomeFeature] {
        [
            HomeFeature(id: "email", title: "Email", icon: "envelope", isComingSoon: false) {
                openEmailCompose()
            },
            HomeFeature(id: "clipboard", title: "Clipboard", icon: "list.clipboard", isComingSoon: false) {
                showClipboard = true
            },
            HomeFeature(id: "chat_context", title: "Chat with Context", icon: "photo.on.rectangle", isComingSoon: false) {
                openUploadContext()
            },
            HomeFeature(id: "voice_ai", title: "Voice to Text", icon: "waveform", isComingSoon: true) {
                // Coming soon
            }
        ]
    }
    
    private func openEmailCompose() {
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(true, forKey: "PendingEmailCompose")
            defaults.set(Date(), forKey: "EmailComposeRequestTime")
            defaults.synchronize()
        }
        
        if let url = URL(string: "socialwand://email") {
            openURL(url)
        }
    }

    private func openUploadContext() {
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(true, forKey: "PendingPhotoUpload")
            defaults.set("instagram", forKey: "PhotoUploadSourceApp")
            defaults.set(Date(), forKey: "PhotoUploadRequestTime")
            defaults.synchronize()
        }
        
        if let url = URL(string: "socialwand://upload?source=instagram") {
            openURL(url)
        }
    }
    
    private func handleClipboardPaste(_ clip: ClipboardItem) {
        #if canImport(UIKit)
        switch clip.type {
        case .text:
            if let text = clip.textContent {
                UIPasteboard.general.string = text
            }
        case .image:
            if let imageFilename = clip.imageFilename,
               let imageURL = ClipboardManager.shared.getImageURL(filename: imageFilename),
               let imageData = try? Data(contentsOf: imageURL),
               let image = UIImage(data: imageData) {
                UIPasteboard.general.image = image
            }
        }
        AppHapticHelper.triggerHaptic(style: .medium)
        #endif
        showClipboard = false
    }
    
    @ViewBuilder
    private func featureGrid(
        features: [HomeFeature],
        metrics: HomeCardMetrics,
        cardSize: CGSize,
        gridHeight: CGFloat,
        shouldScroll: Bool,
        horizontalPadding: CGFloat,
        cardSpacing: CGFloat,
        gridInnerPadding: CGFloat
    ) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: cardSpacing),
            GridItem(.flexible(), spacing: cardSpacing)
        ]
        
        VStack(alignment: .leading, spacing: metrics.containerSpacing) {
            ScrollView(showsIndicators: shouldScroll) {
                LazyVGrid(columns: columns, spacing: cardSpacing) {
                    ForEach(features) { feature in
                        HomeFeatureCard(
                            feature: feature,
                            metrics: metrics,
                            size: cardSize
                        )
                    }
                }
                .padding(.horizontal, gridInnerPadding)
                .padding(.vertical, gridInnerPadding)
            }
            .scrollDisabled(!shouldScroll)
            .frame(height: gridHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: metrics.containerCornerRadius, style: .continuous)
                .fill(AppBrand.cardBackground.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.containerCornerRadius, style: .continuous)
                .stroke(AppBrand.cardBorder.opacity(0.9), lineWidth: 1)
        )
        .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct HomeFeature: Identifiable {
    let id: String
    let title: String
    let icon: String
    let isComingSoon: Bool
    let action: () -> Void
}

private struct HomeFeatureCard: View {
    let feature: HomeFeature
    let metrics: HomeCardMetrics
    let size: CGSize
    
    var body: some View {
        Button(action: feature.action) {
            ZStack {
                VStack(spacing: metrics.iconTitleSpacing) {
                    Image(systemName: feature.icon)
                        .font(.system(size: metrics.iconSize, weight: .semibold))
                        .foregroundStyle(AppBrand.textPrimary)
                    
                    Text(feature.title)
                        .font(.system(size: metrics.titleFont, weight: .semibold))
                        .foregroundStyle(AppBrand.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: size.width, height: size.height)
                .background(
                    RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
                        .fill(AppBrand.dim)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
                        .stroke(AppBrand.cardBorder, lineWidth: 1)
                )
                .blur(radius: feature.isComingSoon ? 3 : 0)
                
                if feature.isComingSoon {
                    VStack(spacing: 4) {
                        Text("Coming soon")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppBrand.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.6))
                    )
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(feature.isComingSoon)
    }
}

private struct HomeCardMetrics {
    let cardSpacing: CGFloat
    let gridInnerPadding: CGFloat
    let containerSpacing: CGFloat
    let containerCornerRadius: CGFloat
    let cardCornerRadius: CGFloat
    let titleFont: CGFloat
    let iconSize: CGFloat
    let iconTitleSpacing: CGFloat
    let minCardHeight: CGFloat
    let maxCardHeight: CGFloat
    let cardAspect: CGFloat
    
    static func metrics(for breakpoint: LayoutBreakpoint) -> HomeCardMetrics {
        switch breakpoint {
        case .veryCompact:
            return HomeCardMetrics(
                cardSpacing: 12,
                gridInnerPadding: 12,
                containerSpacing: 0,
                containerCornerRadius: 18,
                cardCornerRadius: 16,
                titleFont: 14,
                iconSize: 20,
                iconTitleSpacing: 8,
                minCardHeight: 88,
                maxCardHeight: 110,
                cardAspect: 0.7
            )
        case .compact:
            return HomeCardMetrics(
                cardSpacing: 14,
                gridInnerPadding: 14,
                containerSpacing: 0,
                containerCornerRadius: 20,
                cardCornerRadius: 18,
                titleFont: 15,
                iconSize: 22,
                iconTitleSpacing: 8,
                minCardHeight: 100,
                maxCardHeight: 130,
                cardAspect: 0.72
            )
        case .regular:
            return HomeCardMetrics(
                cardSpacing: 16,
                gridInnerPadding: 16,
                containerSpacing: 0,
                containerCornerRadius: 22,
                cardCornerRadius: 20,
                titleFont: 16,
                iconSize: 24,
                iconTitleSpacing: 10,
                minCardHeight: 112,
                maxCardHeight: 150,
                cardAspect: 0.75
            )
        }
    }
}

private struct HomeGridLayout {
    let cardSpacing: CGFloat
    let gridInnerPadding: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let gridHeight: CGFloat
}

private func gridLayout(availableWidth: CGFloat, metrics: HomeCardMetrics) -> HomeGridLayout {
    let minCardWidth: CGFloat = 80
    var cardSpacing = min(24, max(metrics.cardSpacing, availableWidth * 0.04))
    var gridInnerPadding = min(24, max(metrics.gridInnerPadding, availableWidth * 0.04))
    let requiredWidth = (minCardWidth * 2) + (gridInnerPadding * 2) + cardSpacing
    if requiredWidth > availableWidth {
        let excess = requiredWidth - availableWidth
        let paddingReduction = min(excess, gridInnerPadding * 2)
        gridInnerPadding -= paddingReduction / 2
        let remaining = excess - paddingReduction
        if remaining > 0 {
            cardSpacing = max(6, cardSpacing - remaining)
        }
    }
    let cardWidth = max(1, (availableWidth - (gridInnerPadding * 2) - cardSpacing) / 2)
    let cardHeight = max(metrics.minCardHeight, min(metrics.maxCardHeight, cardWidth * metrics.cardAspect))
    let gridHeight = (cardHeight * 2) + cardSpacing + (gridInnerPadding * 2)
    return HomeGridLayout(
        cardSpacing: cardSpacing,
        gridInnerPadding: gridInnerPadding,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        gridHeight: gridHeight
    )
}

#Preview {
    HomeView()
}
