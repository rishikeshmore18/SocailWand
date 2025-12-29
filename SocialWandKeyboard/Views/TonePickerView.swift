//
//  TonePickerView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

// MARK: - Models

struct ToneOption: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let isComingSoon: Bool
}

// MARK: - Main View

struct TonePickerView: View {
    
    let onApply: ([String]) -> Void
    let onSave: ([String]) -> Void  // Still called, but automatically
    let onCancel: () -> Void
    let onClear: () -> Void  // Still called, but automatically
    let savedPreferences: [String]
    let hasTextContent: Bool
    let showDoneButton: Bool  // true = main app, false = keyboard
    
    @State private var selectedIDs: Set<String> = []
    @State private var showComingSoon: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    private let maxSelections = 3
    
    private let tones: [ToneOption] = [
        ToneOption(id: "assertive", title: "Assertive", emoji: "💪", isComingSoon: false),
        ToneOption(id: "confident", title: "Confident", emoji: "😎", isComingSoon: false),
        ToneOption(id: "playful", title: "Playful", emoji: "😜", isComingSoon: false),
        ToneOption(id: "empathetic", title: "Empathetic", emoji: "😌", isComingSoon: false),
        ToneOption(id: "flirtatious", title: "Flirtatious", emoji: "💋", isComingSoon: false),
        ToneOption(id: "professional", title: "Professional", emoji: "💼", isComingSoon: false),
        ToneOption(id: "casual", title: "Casual", emoji: "🤙", isComingSoon: false),
        ToneOption(id: "custom", title: "Custom", emoji: "✨", isComingSoon: true)
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
                        .padding(.bottom, 120)
                    }
                }
                
                // ✅ Show Done button for main app, Gen button for keyboard
                if showDoneButton {
                    doneButton()
                } else if !selectedIDs.isEmpty && hasTextContent {
                    genButton(metrics: metrics)
                }
            }
            .overlay(comingSoonToast)
            .onAppear {
                if selectedIDs.isEmpty && !savedPreferences.isEmpty {
                    selectedIDs = Set(savedPreferences)
                    print("✅ Pre-selected saved tones: \(savedPreferences)")
                }
            }
        }
    }
    
    private func header(metrics: ToneCardMetrics) -> some View {
        HStack(spacing: 8) {
            Text("Choose Tone")
                .font(.system(size: metrics.headerFont, weight: .bold))
                .foregroundColor(.primary)
            
            Text("•")
                .foregroundColor(.secondary)
                .font(.system(size: metrics.subtitleFont))
            
            Text(selectedIDs.isEmpty ? "How should this sound?" : "\(selectedIDs.count)/\(maxSelections) selected")
                .font(.system(size: metrics.subtitleFont))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    // ✅ NEW: Single Gen button (bottom right corner)
    private func genButton(metrics: ToneCardMetrics) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: handleGenerate) {
                    Text("Gen")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 46)
                }
                .buttonStyle(CornerButtonStyle(color: Color(hex: "8B5CF6")))
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.bottom, 16)
        }
    }
    
    // ✅ DONE BUTTON: Full-width button bottom (for Add Context page)
    private func doneButton() -> some View {
        VStack {
            Spacer()
            Button(action: {
                triggerHaptic(style: .medium)
                onCancel()
            }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
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
    
    // ✅ CHANGED: Auto-save on every tap
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
                // Deselect - remove from set
                selectedIDs.remove(tone.id)
            } else if selectedIDs.count < maxSelections {
                // Select - add to set
                selectedIDs.insert(tone.id)
            } else {
                // Max selections reached
                triggerHaptic(style: .rigid)
                return
            }
        }
        
        // ✅ AUTO-SAVE: Immediately save to App Group
        autoSave()
    }
    
    // ✅ NEW: Auto-save helper
    private func autoSave() {
        if selectedIDs.isEmpty {
            // No selections - clear saved preferences
            onClear()
            print("✅ Auto-cleared tone preferences")
        } else {
            // Has selections - save them
            let selectedToneIDs = Array(selectedIDs)
            onSave(selectedToneIDs)
            print("✅ Auto-saved tone preferences: \(selectedToneIDs)")
        }
    }
    
    private func handleGenerate() {
        guard !selectedIDs.isEmpty else { return }
        
        let selectedTitles = tones
            .filter { selectedIDs.contains($0.id) }
            .map { $0.title }
        
        triggerHaptic(style: .medium)
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
            ZStack {
                HStack(spacing: 12) {
                    Spacer()
                    
                    Text(option.emoji)
                        .font(.system(size: metrics.emojiFont))
                    
                    Text(option.title)
                        .font(.system(size: metrics.titleFont, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                if isSelected {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .padding(.trailing, 16)
                    }
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .opacity(isDisabled && !isSelected ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isSelected)
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(Color(UIColor.systemBackground))
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .strokeBorder(
                isSelected ? Color(hex: "8B5CF6") : Color.gray.opacity(0.3),
                lineWidth: isSelected ? metrics.borderWidth : 1.5
            )
            .shadow(
                color: isSelected ? Color(hex: "8B5CF6").opacity(0.30) : .clear,
                radius: 12,
                y: 6
            )
    }
}

// MARK: - Button Styles

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
                cornerRadius: 16, borderWidth: 3, innerSpacing: 12, contentTopPadding: 8
            )
        case .medium:
            return ToneCardMetrics(
                horizontalPadding: 18, verticalPadding: 14, cardSpacing: 12,
                titleFont: 17, subtitleFont: 14, emojiFont: 22,
                headerFont: 20, ctaFont: 17, ctaHeight: 52, ctaSpacing: 14,
                cornerRadius: 18, borderWidth: 3, innerSpacing: 14, contentTopPadding: 12
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
