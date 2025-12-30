//
//  TonePickerView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

// MARK: - Constants

private let appGroupID = "group.rishi-more.social-wand"

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
    @State private var savedLengthPreference: String? = nil
    @State private var showLengthDropdown: Bool = false
    @State private var showBlurOverlay: Bool = false
    @State private var syncTimer: Timer? = nil
    
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
                
                // Blur overlay (appears when dropdown is open)
                blurOverlay
                
                // Dropdown menu (high z-index, positioned relative to header)
                if showLengthDropdown {
                    GeometryReader { geo in
                        VStack {
                            HStack {
                                Spacer()
                                lengthDropdownMenu(metrics: metrics)
                                    .offset(x: -16, y: 72)  // 72 = header height (60) + small gap (12)
                            }
                            Spacer()
                        }
                    }
                    .zIndex(100)
                }
                
                // ✅ Show Done button for main app, Gen button for keyboard
                if showDoneButton {
                    doneButton()
                } else if !selectedIDs.isEmpty && hasTextContent {
                    genButton(metrics: metrics)
                }
            }
            .overlay(comingSoonToast)
            .onTapGesture {
                // Close dropdown if tapping outside
                if showLengthDropdown {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showLengthDropdown = false
                        showBlurOverlay = false
                    }
                }
            }
            .onAppear {
                if selectedIDs.isEmpty && !savedPreferences.isEmpty {
                    selectedIDs = Set(savedPreferences)
                    print("✅ Pre-selected saved tones: \(savedPreferences)")
                }
                loadSavedLength()
                
                // Set up listener for App Group changes
                NotificationCenter.default.addObserver(
                    forName: UserDefaults.didChangeNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Force reload from App Group on any UserDefaults change
                    loadSavedLength()
                }
                
                // Poll for changes every 0.5 seconds (ensures sync)
                syncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    loadSavedLength()
                }
            }
            .onDisappear {
                // Clean up timer
                syncTimer?.invalidate()
                syncTimer = nil
            }
        }
    }
    
    private func header(metrics: ToneCardMetrics) -> some View {
        HStack(spacing: 12) {
            // Left: Selection count
            Text("\(selectedIDs.count)/\(maxSelections) selected")
                .font(.system(size: metrics.subtitleFont, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Right: Length dropdown button
            lengthButton(metrics: metrics)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    @ViewBuilder
    private func lengthButton(metrics: ToneCardMetrics) -> some View {
        if let selectedLength = savedLengthPreference {
            // Show selected length with X button
            HStack(spacing: 6) {
                // Tappable chip body (opens dropdown)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showLengthDropdown.toggle()
                        showBlurOverlay = showLengthDropdown
                    }
                    triggerHaptic(style: .light)
                }) {
                    Text(selectedLength.capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.leading, 12)
                        .padding(.vertical, 6)
                }
                
                // Tappable X icon (clears selection)
                Button(action: {
                    clearLength()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        } else {
            // Show dropdown button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showLengthDropdown.toggle()
                    showBlurOverlay = showLengthDropdown
                }
                triggerHaptic(style: .light)
            }) {
                HStack(spacing: 4) {
                    Text("Length")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                .cornerRadius(16)
            }
        }
    }
    
    private func lengthDropdownMenu(metrics: ToneCardMetrics) -> some View {
        VStack(spacing: 0) {
            ForEach([
                LengthOption(id: "short", title: "Short", emoji: "⚡"),
                LengthOption(id: "medium", title: "Medium", emoji: "⚖️"),
                LengthOption(id: "long", title: "Long", emoji: "📜")
            ]) { option in
                Button(action: {
                    selectLength(option.id)
                }) {
                    HStack(spacing: 8) {
                        Text(option.emoji)
                            .font(.system(size: 16))
                        
                        Text(option.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if savedLengthPreference == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "8B5CF6"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        savedLengthPreference == option.id
                            ? Color(hex: "8B5CF6").opacity(0.1)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
                
                if option.id != "long" {
                    Divider()
                        .padding(.horizontal, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
        )
        .frame(width: 140)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
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
    
    private func selectLength(_ lengthID: String) {
        savedLengthPreference = lengthID
        
        // Save to App Group
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(lengthID, forKey: "SavedLengthPreference")
            defaults.synchronize()
            print("✅ Saved length preference from TonePicker: \(lengthID)")
        }
        
        // Broadcast change to other views
        NotificationCenter.default.post(
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Close dropdown and blur
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showLengthDropdown = false
            showBlurOverlay = false
        }
        
        triggerHaptic(style: .medium)
    }
    
    private func clearLength() {
        savedLengthPreference = nil
        
        // Clear from App Group
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.removeObject(forKey: "SavedLengthPreference")
            defaults.synchronize()
            print("✅ Cleared length preference from TonePicker")
        }
        
        // Broadcast change to other views
        NotificationCenter.default.post(
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        triggerHaptic(style: .light)
    }
    
    private func loadSavedLength() {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            let saved = defaults.string(forKey: "SavedLengthPreference")
            
            // Only update if changed (prevents unnecessary re-renders)
            if saved != savedLengthPreference {
                savedLengthPreference = saved
                if let unwrapped = saved {
                    print("✅ Synced length in TonePicker: \(unwrapped)")
                } else {
                    print("✅ Cleared length in TonePicker")
                }
            }
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
    
    @ViewBuilder
    private var blurOverlay: some View {
        if showBlurOverlay {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showLengthDropdown = false
                        showBlurOverlay = false
                    }
                }
                .zIndex(99)
        } else {
            Color.clear
                .ignoresSafeArea()
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
