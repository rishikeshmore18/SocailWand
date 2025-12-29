//
//  LengthPickerView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

// MARK: - Models

struct LengthOption: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Main View

struct LengthPickerView: View {
    
    let onApply: (String) -> Void
    let onSave: (String) -> Void  // Still called, but automatically
    let onCancel: () -> Void
    let onClear: () -> Void  // Still called, but automatically
    let savedPreference: String?
    let hasTextContent: Bool
    let showDoneButton: Bool  // true = main app, false = keyboard
    
    @State private var selectedID: String? = nil
    @State private var didSyncFromSaved = false
    
    @Environment(\.colorScheme) var colorScheme
    
    private let lengths: [LengthOption] = [
        LengthOption(id: "short", title: "Short", emoji: "⚡"),
        LengthOption(id: "medium", title: "Medium", emoji: "⚖️"),
        LengthOption(id: "long", title: "Long", emoji: "📜")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let breakpoint = KeyboardBreakpoint.from(height: geometry.size.height)
            let metrics = LengthCardMetrics.metrics(for: breakpoint)
            
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header(metrics: metrics)
                    
                    ScrollView {
                        VStack(spacing: metrics.cardSpacing) {
                            ForEach(lengths) { length in
                                LengthCard(
                                    option: length,
                                    metrics: metrics,
                                    isSelected: selectedID == length.id
                                ) {
                                    handleLengthTap(length)
                                }
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.contentTopPadding)
                        .padding(.bottom, 120)
                    }
                }
                
                // ✅ Show Done button for main app, Gen button for keyboard
                // ✅ Gen is now INVISIBLE when there’s no text (instead of dimmed/disabled)
                if showDoneButton {
                    doneButton()
                } else if selectedID != nil && hasTextContent {
                    genButton(metrics: metrics)
                }
            }
            .onAppear {
                syncSelectionFromSavedPreference()
            }
            .onChange(of: savedPreference) { _ in
                // If the parent loads/saves from App Group asynchronously,
                // this keeps the UI (and Gen button) consistent.
                syncSelectionFromSavedPreference()
            }
        }
    }
    
    // ✅ Keep local selection in sync with the persisted preference
    // This prevents the Gen button from randomly disappearing when switching
    // between toolbar tabs and coming back to Length.
    private func syncSelectionFromSavedPreference() {
        // Only do an initial sync once per view lifetime, OR anytime the saved value changes.
        if let saved = savedPreference {
            if selectedID != saved {
                selectedID = saved
                print("✅ Synced saved length into UI: \(saved)")
            } else {
                // Still mark as synced so we don't rely on repeated onAppear calls
                print("✅ Length already in sync: \(saved)")
            }
            didSyncFromSaved = true
        } else {
            // If there is no saved preference, don't overwrite an in-progress UI selection.
            // (User may have selected something but persistence may lag.)
            if !didSyncFromSaved {
                print("ℹ️ No saved length preference to sync")
                didSyncFromSaved = true
            }
        }
    }
    
    private func header(metrics: LengthCardMetrics) -> some View {
        HStack(spacing: 8) {
            Text("Choose Length")
                .font(.system(size: metrics.headerFont, weight: .bold))
                .foregroundColor(.primary)
            
            Text("•")
                .foregroundColor(.secondary)
                .font(.system(size: metrics.subtitleFont))
            
            Text(selectedID == nil ? "How long should it be?" : "1/1 selected")
                .font(.system(size: metrics.subtitleFont))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(backgroundColor.opacity(0.95))
    }
    
    // ✅ Single Gen button (bottom right corner)
    private func genButton(metrics: LengthCardMetrics) -> some View {
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
    
    // ✅ Auto-save on every tap
    private func handleLengthTap(_ length: LengthOption) {
        triggerHaptic(style: .light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if selectedID == length.id {
                // Deselect - clear selection
                selectedID = nil
            } else {
                // Select - set new selection
                selectedID = length.id
            }
        }
        
        // ✅ AUTO-SAVE: Immediately save to App Group
        autoSave()
    }
    
    // ✅ Auto-save helper
    private func autoSave() {
        if selectedID == nil {
            // No selection - clear saved preference
            onClear()
            print("✅ Auto-cleared length preference")
        } else {
            // Has selection - save it
            onSave(selectedID!)
            print("✅ Auto-saved length preference: \(selectedID!)")
        }
    }
    
    private func handleGenerate() {
        // Gen button is only shown when hasTextContent == true,
        // but keep this guard anyway to avoid weird edge cases.
        guard let selected = selectedID, hasTextContent else { return }
        
        let selectedTitle = lengths.first(where: { $0.id == selected })?.title ?? selected
        
        triggerHaptic(style: .medium)
        onApply(selectedTitle)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Length Card

private struct LengthCard: View {
    let option: LengthOption
    let metrics: LengthCardMetrics
    let isSelected: Bool
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
        }
        .buttonStyle(.plain)
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

private struct LengthCardMetrics {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cardSpacing: CGFloat
    let titleFont: CGFloat
    let subtitleFont: CGFloat
    let emojiFont: CGFloat
    let headerFont: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let contentTopPadding: CGFloat
    
    static func metrics(for breakpoint: KeyboardBreakpoint) -> LengthCardMetrics {
        switch breakpoint {
        case .small:
            return LengthCardMetrics(
                horizontalPadding: 16, verticalPadding: 12, cardSpacing: 10,
                titleFont: 16, subtitleFont: 13, emojiFont: 20,
                headerFont: 18, cornerRadius: 16, borderWidth: 3, contentTopPadding: 8
            )
        case .medium:
            return LengthCardMetrics(
                horizontalPadding: 18, verticalPadding: 14, cardSpacing: 12,
                titleFont: 17, subtitleFont: 14, emojiFont: 22,
                headerFont: 20, cornerRadius: 18, borderWidth: 3, contentTopPadding: 12
            )
        case .large:
            return LengthCardMetrics(
                horizontalPadding: 20, verticalPadding: 16, cardSpacing: 14,
                titleFont: 18, subtitleFont: 15, emojiFont: 24,
                headerFont: 22, cornerRadius: 20, borderWidth: 3, contentTopPadding: 16
            )
        }
    }
}
