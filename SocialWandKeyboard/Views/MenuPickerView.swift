//
//  MenuPickerView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

// MARK: - Models

struct MenuOption: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let isComingSoon: Bool
}

// MARK: - Main View

struct MenuPickerView: View {
    let onPaste: () -> Void
    let onClipboard: () -> Void
    let onSettings: () -> Void
    let onCancel: () -> Void
    let onUpload: (() -> Void)?
    let onReply: (() -> Void)?
    let onRewrite: (() -> Void)?
    let onTone: (() -> Void)?
    let onLength: (() -> Void)?
    let onTranslate: (() -> Void)?
    let onEmail: (() -> Void)?
    
    @State private var showComingSoon: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    private var menuOptions: [MenuOption] {
        let appGroupID = "group.com.rishimore.socialwand"

        let allOptions: [String: MenuOption] = [
            "upload": MenuOption(id: "upload", title: "Upload Context", icon: "photo.on.rectangle", isComingSoon: false),
            "reply": MenuOption(id: "reply", title: "Reply", icon: "arrowshape.turn.up.left", isComingSoon: false),
            "rewrite": MenuOption(id: "rewrite", title: "Rewrite", icon: "pencil.line", isComingSoon: false),
            "translate": MenuOption(id: "translate", title: "Translate", icon: "globe", isComingSoon: false),
            "email": MenuOption(id: "email", title: "Email", icon: "envelope", isComingSoon: false),
            "tone": MenuOption(id: "tone", title: "Tone", icon: "waveform", isComingSoon: false),
            "length": MenuOption(id: "length", title: "Length", icon: "text.alignleft", isComingSoon: false),
            "save": MenuOption(id: "save", title: "Save to Clipboard", icon: "square.and.arrow.down", isComingSoon: false),
            "clipboard": MenuOption(id: "clipboard", title: "Clipboard", icon: "list.clipboard", isComingSoon: false),
            "settings": MenuOption(id: "settings", title: "Settings", icon: "gearshape", isComingSoon: false)
        ]

        let defaultOrder = [
            "upload",
            "reply",
            "rewrite",
            "translate",
            "email",
            "tone",
            "length",
            "save",
            "clipboard",
            "settings"
        ]

        if let defaults = UserDefaults(suiteName: appGroupID),
           let savedOrder = defaults.stringArray(forKey: "ToolbarButtonOrder") {
            let storedCount = defaults.object(forKey: "ToolbarButtonCount") as? Int
            let toolbarCount = min(max(storedCount ?? 4, 0), savedOrder.count)

            let menuIDs = Array(savedOrder.dropFirst(toolbarCount)).filter { $0 != "settings" }
            let menuOptions = menuIDs.compactMap { allOptions[$0] }

            if !menuOptions.isEmpty {
                return menuOptions
            }
        }

        let fallbackIDs = Array(defaultOrder.dropFirst(4)).filter { $0 != "settings" }
        return fallbackIDs.compactMap { allOptions[$0] }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let breakpoint = KeyboardBreakpoint.from(height: geometry.size.height)
            let metrics = MenuCardMetrics.metrics(for: breakpoint)
            
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header(metrics: metrics)
                    
                    ScrollView {
                        let columns = Array(
                            repeating: GridItem(.flexible(), spacing: metrics.cardSpacing),
                            count: 3
                        )

                        LazyVGrid(columns: columns, spacing: metrics.cardSpacing) {
                            ForEach(menuOptions) { option in
                                MenuCard(
                                    option: option,
                                    metrics: metrics,
                                    isDisabled: option.isComingSoon
                                ) {
                                    handleMenuTap(option)
                                }
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.contentTopPadding)
                        .padding(.bottom, 80)
                    }
                }
            }
            .overlay(comingSoonToast)
        }
    }
    
    private func header(metrics: MenuCardMetrics) -> some View {
        HStack(spacing: 8) {
            Text("Menu")
                .font(.system(size: metrics.headerFont, weight: .bold))
                .foregroundColor(.primary)
            
            Text("•")
                .foregroundColor(.secondary)
                .font(.system(size: metrics.subtitleFont))
            
            Text("Quick actions")
                .font(.system(size: metrics.subtitleFont))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onCancel) {
                Text("Close")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "8B5CF6"))
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(backgroundColor.opacity(0.95) as Color)
    }
    
    private func handleMenuTap(_ option: MenuOption) {
        if option.isComingSoon {
            triggerHaptic(style: .rigid)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showComingSoon = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showComingSoon = false
                }
            }
            return
        }
        
        // Handle menu option based on ID
        switch option.id {
        case "save":  // Changed from "paste"
            triggerHaptic(style: .medium)
            onPaste()
            onCancel()  // Close menu after action
        case "clipboard":
            triggerHaptic(style: .light)
            onClipboard()
            onCancel()  // Close menu after action
        case "settings":
            triggerHaptic(style: .medium)
            onSettings()
            onCancel()  // Close menu after action
        case "upload":
            triggerHaptic(style: .light)
            onCancel()  // Close menu first
            onUpload?()  // Then trigger upload action
        case "reply":
            triggerHaptic(style: .light)
            onCancel()  // Close menu first
            onReply?()  // Then trigger reply action
        case "rewrite":
            triggerHaptic(style: .light)
            onCancel()  // Close menu first
            onRewrite?()  // Then trigger rewrite action
        case "tone":
            triggerHaptic(style: .light)
            onCancel()  // Close menu first
            onTone?()  // Then trigger tone action
        case "length":
            triggerHaptic(style: .light)
            onCancel()  // Close menu first
            onLength?()  // Then trigger length action
        case "translate":
            triggerHaptic(style: .light)
            onCancel()
            onTranslate?()
        case "email":
            triggerHaptic(style: .light)
            onCancel()
            onEmail?()
        default:
            break
        }
    }
    
    @ViewBuilder
    private var comingSoonToast: some View {
        if showComingSoon {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Text("✨")
                        .font(.system(size: 18))
                    Text("Coming soon!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.bottom, 100)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticHelper.triggerHaptic(style: style)
    }
}

// MARK: - Menu Card

private struct MenuCard: View {
    let option: MenuOption
    let metrics: MenuCardMetrics
    let isDisabled: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: metrics.iconTitleSpacing) {
                Image(systemName: option.icon)
                    .font(.system(size: metrics.iconFont))
                    .foregroundColor(.primary)

                Text(option.title)
                    .font(.system(size: metrics.titleFont, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: metrics.cardHeight)
            .padding(.vertical, metrics.verticalPadding)
            .padding(.horizontal, metrics.cardInnerPadding)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .opacity(isDisabled ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(Color(UIColor.systemBackground))
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .strokeBorder(
                Color.gray.opacity(0.3),
                lineWidth: 1.5
            )
    }
}

// MARK: - Breakpoint & Metrics

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

private struct MenuCardMetrics {
    let horizontalPadding: CGFloat
    let cardInnerPadding: CGFloat
    let verticalPadding: CGFloat
    let cardSpacing: CGFloat
    let titleFont: CGFloat
    let subtitleFont: CGFloat
    let iconFont: CGFloat
    let headerFont: CGFloat
    let cornerRadius: CGFloat
    let contentTopPadding: CGFloat
    let cardHeight: CGFloat
    let iconTitleSpacing: CGFloat
    
    static func metrics(for breakpoint: KeyboardBreakpoint) -> MenuCardMetrics {
        switch breakpoint {
        case .small:
            return MenuCardMetrics(
                horizontalPadding: 16,
                cardInnerPadding: 10,
                verticalPadding: 10,
                cardSpacing: 10,
                titleFont: 15,
                subtitleFont: 13,
                iconFont: 18,
                headerFont: 18,
                cornerRadius: 16,
                contentTopPadding: 8,
                cardHeight: 64,
                iconTitleSpacing: 6
            )
        case .medium:
            return MenuCardMetrics(
                horizontalPadding: 18,
                cardInnerPadding: 12,
                verticalPadding: 12,
                cardSpacing: 12,
                titleFont: 16,
                subtitleFont: 14,
                iconFont: 20,
                headerFont: 20,
                cornerRadius: 18,
                contentTopPadding: 12,
                cardHeight: 72,
                iconTitleSpacing: 8
            )
        case .large:
            return MenuCardMetrics(
                horizontalPadding: 20,
                cardInnerPadding: 14,
                verticalPadding: 14,
                cardSpacing: 14,
                titleFont: 17,
                subtitleFont: 15,
                iconFont: 22,
                headerFont: 22,
                cornerRadius: 20,
                contentTopPadding: 16,
                cardHeight: 80,
                iconTitleSpacing: 10
            )
        }
    }
}
