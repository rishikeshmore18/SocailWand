//
//  TonePickerView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

// MARK: - Models

// Note: Color(hex:) extension is defined in WandIcon.swift and available to all files in this module

struct ToneOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let emoji: String
    let isComingSoon: Bool
}

// MARK: - Main View

struct TonePickerView: View {
    
    let onApply: ([String]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedIDs: Set<String> = []
    @State private var showComingSoon: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    private let maxSelections = 3
    
    private let tones: [ToneOption] = [
        ToneOption(id: "assertive", title: "Assertive", subtitle: "Stand your ground", emoji: "💪", isComingSoon: false),
        ToneOption(id: "confident", title: "Confident", subtitle: "Own your message", emoji: "😎", isComingSoon: false),
        ToneOption(id: "playful", title: "Playful", subtitle: "Keep it fun", emoji: "😜", isComingSoon: false),
        ToneOption(id: "empathetic", title: "Empathetic", subtitle: "Show you care", emoji: "😌", isComingSoon: false),
        ToneOption(id: "flirtatious", title: "Flirtatious", subtitle: "Turn up the charm", emoji: "💋", isComingSoon: false),
        ToneOption(id: "professional", title: "Professional", subtitle: "Keep it polished", emoji: "💼", isComingSoon: false),
        ToneOption(id: "casual", title: "Casual", subtitle: "Stay relaxed", emoji: "🤙", isComingSoon: false),
        ToneOption(id: "custom", title: "Custom", subtitle: "Coming soon", emoji: "✨", isComingSoon: true)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let breakpoint = KeyboardBreakpoint.from(height: geometry.size.height)
            let metrics = ToneCardMetrics.metrics(for: breakpoint)
            
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header(metrics: metrics)
                    
                    ScrollView {
                        VStack(spacing: metrics.cardSpacing) {
                            ForEach(tones) { tone in
                                ToneCard(
                                    option: tone,
                                    metrics: metrics,
                                    isSelected: selectedIDs.contains(tone.id),
                                    isDisabled: tone.isComingSoon || (!selectedIDs.contains(tone.id) && selectedIDs.count >= maxSelections)
                                ) {
                                    handleToneTap(tone)
                                }
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.contentTopPadding)
                        .padding(.bottom, metrics.ctaHeight + metrics.ctaSpacing + 20)
                    }
                }
                
                VStack {
                    Spacer()
                    applyButton(metrics: metrics)
                }
            }
            .overlay(comingSoonToast)
        }
    }
    
    private func header(metrics: ToneCardMetrics) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Tone")
                    .font(.system(size: metrics.headerFont, weight: .bold))
                    .foregroundColor(.white)
                Text(selectedIDs.isEmpty ? "How should this sound?" : "\(selectedIDs.count)/\(maxSelections) selected")
                    .font(.system(size: metrics.subtitleFont))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    private func applyButton(metrics: ToneCardMetrics) -> some View {
        Button(action: handleApply) {
            Text("Apply Changes")
                .font(.system(size: metrics.ctaFont, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.ctaHeight)
        }
        .buttonStyle(ToneApplyButtonStyle())
        .disabled(selectedIDs.isEmpty)
        .opacity(selectedIDs.isEmpty ? 0.45 : 1)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.bottom, 16)
        .background(
            backgroundColor.opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
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
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.bottom, 100)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
    
    private func handleToneTap(_ tone: ToneOption) {
        if tone.isComingSoon {
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
        
        triggerHaptic(style: .light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if selectedIDs.contains(tone.id) {
                selectedIDs.remove(tone.id)
            } else if selectedIDs.count < maxSelections {
                selectedIDs.insert(tone.id)
            } else {
                triggerHaptic(style: .rigid)
            }
        }
    }
    
    private func handleApply() {
        guard !selectedIDs.isEmpty else { return }
        
        let selectedTitles = tones
            .filter { selectedIDs.contains($0.id) }
            .map { $0.title }
        
        onApply(selectedTitles)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Tone Card

private struct ToneCard: View {
    let option: ToneOption
    let metrics: ToneCardMetrics
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.innerSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(option.title)
                            .font(.system(size: metrics.titleFont, weight: .semibold))
                            .foregroundColor(textColor)
                        Text(option.emoji)
                            .font(.system(size: metrics.emojiFont))
                    }
                    Text(option.subtitle)
                        .font(.system(size: metrics.subtitleFont))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "8B5CF6"))
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .opacity(isDisabled && !isSelected ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isSelected)
    }
    
    private var textColor: Color {
        if option.isComingSoon {
            return Color.secondary
        }
        return .white
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(
                (colorScheme == .dark ? Color(white: 0.15) : Color.white)
                    .opacity(isSelected ? 0.65 : 0.45)
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .strokeBorder(
                isSelected ? Color(hex: "8B5CF6") : Color(hex: "262626"),
                lineWidth: isSelected ? metrics.borderWidth : 1
            )
            .shadow(
                color: isSelected ? Color(hex: "8B5CF6").opacity(0.30) : .clear,
                radius: 12,
                y: 6
            )
    }
}

// MARK: - Button Style

private struct ToneApplyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 18, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
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

private struct ToneCardMetrics {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cardSpacing: CGFloat
    let titleFont: CGFloat
    let subtitleFont: CGFloat
    let emojiFont: CGFloat
    let headerFont: CGFloat
    let ctaFont: CGFloat
    let ctaHeight: CGFloat
    let ctaSpacing: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let innerSpacing: CGFloat
    let contentTopPadding: CGFloat
    
    static func metrics(for breakpoint: KeyboardBreakpoint) -> ToneCardMetrics {
        switch breakpoint {
        case .small:
            return ToneCardMetrics(
                horizontalPadding: 16, verticalPadding: 12, cardSpacing: 10,
                titleFont: 16, subtitleFont: 13, emojiFont: 20,
                headerFont: 18, ctaFont: 16, ctaHeight: 48, ctaSpacing: 12,
                cornerRadius: 16, borderWidth: 2, innerSpacing: 12, contentTopPadding: 8
            )
        case .medium:
            return ToneCardMetrics(
                horizontalPadding: 18, verticalPadding: 14, cardSpacing: 12,
                titleFont: 17, subtitleFont: 14, emojiFont: 22,
                headerFont: 20, ctaFont: 17, ctaHeight: 52, ctaSpacing: 14,
                cornerRadius: 18, borderWidth: 2.5, innerSpacing: 14, contentTopPadding: 12
            )
        case .large:
            return ToneCardMetrics(
                horizontalPadding: 20, verticalPadding: 16, cardSpacing: 14,
                titleFont: 18, subtitleFont: 15, emojiFont: 24,
                headerFont: 22, ctaFont: 18, ctaHeight: 54, ctaSpacing: 16,
                cornerRadius: 20, borderWidth: 3, innerSpacing: 16, contentTopPadding: 16
            )
        }
    }
}

