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
    
    @State private var showComingSoon: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    private let menuOptions: [MenuOption] = [
        MenuOption(id: "paste", title: "Paste to Wand Clipboard", icon: "doc.on.clipboard", isComingSoon: false),
        MenuOption(id: "clipboard", title: "Clipboard", icon: "list.clipboard", isComingSoon: false),
        MenuOption(id: "settings", title: "Settings", icon: "gearshape", isComingSoon: false),
        MenuOption(id: "comingSoon", title: "Coming Soon", icon: "sparkles", isComingSoon: true)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let breakpoint = KeyboardBreakpoint.from(height: geometry.size.height)
            let metrics = MenuCardMetrics.metrics(for: breakpoint)
            
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header(metrics: metrics)
                    
                    ScrollView {
                        VStack(spacing: metrics.cardSpacing) {
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
        
        switch option.id {
        case "paste":
            triggerHaptic(style: .medium)
            onPaste()
        case "clipboard":
            triggerHaptic(style: .light)
            onClipboard()
        case "settings":
            triggerHaptic(style: .medium)
            onSettings()
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
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
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
            ZStack {
                HStack(spacing: 12) {
                    Spacer()
                    
                    Image(systemName: option.icon)
                        .font(.system(size: metrics.iconFont))
                        .foregroundColor(.primary)
                    
                    Text(option.title)
                        .font(.system(size: metrics.titleFont, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
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
    let verticalPadding: CGFloat
    let cardSpacing: CGFloat
    let titleFont: CGFloat
    let subtitleFont: CGFloat
    let iconFont: CGFloat
    let headerFont: CGFloat
    let cornerRadius: CGFloat
    let contentTopPadding: CGFloat
    
    static func metrics(for breakpoint: KeyboardBreakpoint) -> MenuCardMetrics {
        switch breakpoint {
        case .small:
            return MenuCardMetrics(
                horizontalPadding: 16,
                verticalPadding: 12,
                cardSpacing: 10,
                titleFont: 16,
                subtitleFont: 13,
                iconFont: 20,
                headerFont: 18,
                cornerRadius: 16,
                contentTopPadding: 8
            )
        case .medium:
            return MenuCardMetrics(
                horizontalPadding: 18,
                verticalPadding: 14,
                cardSpacing: 12,
                titleFont: 17,
                subtitleFont: 14,
                iconFont: 22,
                headerFont: 20,
                cornerRadius: 18,
                contentTopPadding: 12
            )
        case .large:
            return MenuCardMetrics(
                horizontalPadding: 20,
                verticalPadding: 16,
                cardSpacing: 14,
                titleFont: 18,
                subtitleFont: 15,
                iconFont: 24,
                headerFont: 22,
                cornerRadius: 20,
                contentTopPadding: 16
            )
        }
    }
}

