//
//  KeyboardSetupView.swift
//  social wand
//
//  Created by Cursor on 11/13/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct KeyboardSetupView: View {
    let onComplete: () -> Void

        private let instructions: [String] = [
        "Choose \"Keyboards\"",
        "Enable both \"Social Wand\" and \"Allow Full Access\""
    ]
    
    @State private var showFullAccessInfo = false
    @AppStorage(KeyboardPermissionChecker.keyboardReadyKey) private var isKeyboardReady = false

    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets
            let safeHeight = max(geo.size.height - safeInsets.top - safeInsets.bottom, 1)
            let safeWidth = max(geo.size.width - safeInsets.leading - safeInsets.trailing, 1)
            let breakpoint = LayoutBreakpoint.forHeight(safeHeight)

            let headerTop = safeInsets.top + topOffset(for: breakpoint)
            let sidePadding = horizontalPadding(forWidth: safeWidth)
            let ctaHeight = ctaHeight(for: breakpoint)
            let ctaSpacing = ctaSpacing(for: breakpoint)
            let ctaOverlapSpacing = ctaSpacing + ctaHeight * 0.25
            let bottomPadding = bottomPadding(for: breakpoint, safeInsets: safeInsets)
            let available = max(safeHeight - headerTop - ctaHeight - ctaOverlapSpacing - bottomPadding,
                               minHeroHeight(for: breakpoint))

            let heroSpacing = heroSpacing(for: breakpoint)
            let headlineSize = headlineFontSize(for: breakpoint)
            let bulletFont = bulletFontSize(for: breakpoint)
            let bulletSpacing = bulletSpacing(for: breakpoint)
            let screenshotHeight = screenshotHeight(for: breakpoint, available: available)
            let keyboardImage = UIImage(named: "KeyboardAllow")

            VStack(spacing: 0) {
                // Top-aligned headline
                    Text("Set up Keyboard")
                        .font(.system(size: headlineSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .padding(.top, headerTop)
                    .padding(.horizontal, sidePadding)
                        .accessibilityAddTraits(.isHeader)
                        
                Spacer().frame(height: heroSpacing * 1.2)
                
                // Bullet list
                    VStack(alignment: .leading, spacing: bulletSpacing) {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, text in
                            instructionRow(text: text,
                                          bulletFont: bulletFont,
                                          rowSpacing: bulletSpacing / 2)
                        }
                    }
                .frame(maxWidth: heroMaxWidth(for: safeWidth))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, sidePadding)
                                        .accessibilityElement(children: .contain)

                Text("In Settings, go to General → Keyboard → Keyboards → Add New Keyboard → SocialWand → Allow Full Access.")
                    .font(.system(size: bulletFont * 0.95, weight: .regular, design: .rounded))
                    .foregroundStyle(AppBrand.textHint)
                    .padding(.horizontal, sidePadding)
                    .multilineTextAlignment(.leading)
                    .padding(.top, bulletSpacing * 0.8)
                    .accessibilityLabel("Instructions: Settings, General, Keyboard, Keyboards, Add New Keyboard, SocialWand, Allow Full Access")
                
                Spacer().frame(height: heroSpacing * 1.5)
                
                // Large screenshot that will overlap the button
                if let keyboardImage = keyboardImage {
                    Image(uiImage: keyboardImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: screenshotHeight)
                        .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius(for: breakpoint), style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: screenshotCornerRadius(for: breakpoint), style: .continuous)
                                .strokeBorder(AppBrand.cardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, sidePadding)
                        .padding(.bottom, -(ctaHeight * 0.65))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white, location: 0.7),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .accessibilityLabel("Keyboard setup walkthrough screenshot")
                } else {
                    screenshotPlaceholder(height: screenshotHeight, cornerRadius: screenshotCornerRadius(for: breakpoint))
                        .padding(.horizontal, sidePadding)
                        .padding(.bottom, -(ctaHeight * 0.65))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white, location: 0.7),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                                                .accessibilityLabel("Keyboard setup walkthrough screenshot")
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                CTASection(ctaHeight: ctaHeight,
                           ctaFontSize: ctaFontSize(for: breakpoint),
                           ctaSpacing: ctaOverlapSpacing,
                           sidePadding: sidePadding,
                           bottomPadding: bottomPadding,
                           infoFontSize: infoFontSize(for: breakpoint),
                           title: isKeyboardReady ? "Next" : "Go to Settings",
                           showFullAccessInfo: $showFullAccessInfo,
                           action: {
                               if isKeyboardReady {
                                   onComplete()
                               } else {
                               openKeyboardSettings()
                               }
                           })
            }
            .sheet(isPresented: $showFullAccessInfo) {
                FullAccessInfoSheet()
            }
            .onAppear {
                refreshKeyboardStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshKeyboardStatus()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.black.ignoresSafeArea())
    }

    private func instructionRow(text: String, bulletFont: CGFloat, rowSpacing: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: rowSpacing) {
            Circle()
                .fill(AppBrand.purple)
                .frame(width: 6, height: 6)
                .padding(.top, bulletFont * 0.3)

            Text(text)
                .font(.system(size: bulletFont, weight: .regular, design: .rounded))
                .foregroundStyle(AppBrand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func screenshotPlaceholder(height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppBrand.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppBrand.cardBorder, lineWidth: 1)
            )
            .frame(height: height)
            .overlay(
                Text("Screenshot placeholder")
                    .font(.caption)
                    .foregroundStyle(AppBrand.textHint)
            )
    }

    private func openKeyboardSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    private func refreshKeyboardStatus() {
        let ready = KeyboardPermissionChecker.isReady()
        KeyboardPermissionChecker.refreshStatus() // Update global state
        isKeyboardReady = ready // Ensure immediate UI update
    }
}


// MARK: - CTA Section

private struct CTASection: View {
    let ctaHeight: CGFloat
    let ctaFontSize: CGFloat
    let ctaSpacing: CGFloat
    let sidePadding: CGFloat
    let bottomPadding: CGFloat
    let infoFontSize: CGFloat
    let title: String
    @Binding var showFullAccessInfo: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
        Button(action: action) {
            Text(title)
                .font(.system(size: ctaFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: ctaHeight)
        }
        .buttonStyle(PurpleCTAButtonStyle())
            .accessibilityLabel(Text(title))
            
            Button(action: { showFullAccessInfo = true }) {
                Text("What is Full Access?")
                    .font(.system(size: infoFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(AppBrand.textSecondary)
                    .underline()
            }
            .accessibilityLabel("Learn about Full Access permission")
        }
        .padding(.horizontal, sidePadding)
        .padding(.top, ctaSpacing)
        .padding(.bottom, bottomPadding)
        .background(Color.black.opacity(0.92).ignoresSafeArea())
    }
}

private struct PurpleCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    colors: [AppBrand.purple, AppBrand.purpleDark],
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

// MARK: - Full Access Info Sheet

private struct FullAccessInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Full Access is required for Social Wand to:")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        infoRow(icon: "brain", text: "Use AI to analyze context and suggest replies")
                        infoRow(icon: "lock.shield", text: "All processing happens securely on your device")
                        infoRow(icon: "network.slash", text: "Your data is never stored or shared")
                        infoRow(icon: "sparkles", text: "Provide real-time intelligent suggestions")
                    }
                    
                    Text("Without Full Access, the keyboard can only insert basic text and cannot use AI features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("About Full Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppBrand.purple)
                .frame(width: 28)
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Helpers

private extension KeyboardSetupView {
    func horizontalPadding(forWidth width: CGFloat) -> CGFloat {
        width < 340 ? 16 : (width < 420 ? 20 : 24)
    }

    func heroMaxWidth(for width: CGFloat) -> CGFloat {
        min(width, 520)
    }

    func topOffset(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 12
        case .compact:
            return 20
        case .regular:
            return 28
        }
    }

    func logoSize(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 72
        case .compact:
            return 96
        case .regular:
            return 128
        }
    }

    func heroSpacing(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 12
        case .compact:
            return 16
        case .regular:
            return 18
        }
    }

    func headlineFontSize(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 26
        case .compact:
            return 30
        case .regular:
            return 34
        }
    }

    func headlineLineHeightMultiplier(for breakpoint: LayoutBreakpoint) -> CGFloat {
        1.18
    }

    func bulletFontSize(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 14
        case .compact:
            return 15
        case .regular:
            return 16
        }
    }

    func bulletSpacing(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 8
        case .compact:
            return 10
        case .regular:
            return 12
        }
    }

    func screenshotHeight(for breakpoint: LayoutBreakpoint, available: CGFloat) -> CGFloat {
        let proportionalHeight = available * 0.65
        switch breakpoint {
        case .veryCompact:
            return min(max(proportionalHeight, 320), 400)
        case .compact:
            return min(max(proportionalHeight, 380), 480)
        case .regular:
            return min(max(proportionalHeight, 420), 540)
        }
    }

    func screenshotCornerRadius(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 14
        case .compact:
            return 18
        case .regular:
            return 22
        }
    }

    func ctaFontSize(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 17
        case .compact:
            return 19
        case .regular:
            return 20
        }
    }

    func ctaHeight(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 50
        case .compact:
            return 54
        case .regular:
            return 58
        }
    }

    func ctaSpacing(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 12
        case .compact:
            return 14
        case .regular:
            return 16
        }
    }

    func bottomPadding(for breakpoint: LayoutBreakpoint, safeInsets: EdgeInsets) -> CGFloat {
        max(safeInsets.bottom + 14, breakpoint == .veryCompact ? 20 : 28)
    }

    func bottomSpacer(for breakpoint: LayoutBreakpoint, safeInsets: EdgeInsets) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return max(6, safeInsets.bottom * 0.2)
        case .compact:
            return max(10, safeInsets.bottom * 0.25)
        case .regular:
            return max(14, safeInsets.bottom * 0.3)
        }
    }

    func minHeroHeight(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 320
        case .compact:
            return 400
        case .regular:
            return 460
        }
    }
    
    func infoFontSize(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 13
        case .compact:
            return 14
        case .regular:
            return 15
        }
    }
}

// MARK: - Preview

#if DEBUG
struct KeyboardSetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            KeyboardSetupView { }
                .preferredColorScheme(.dark)
                .previewDevice("iPhone SE (3rd generation)")

            KeyboardSetupView { }
                .preferredColorScheme(.dark)
                .previewDevice("iPhone 17 Pro")

            KeyboardSetupView { }
                .preferredColorScheme(.dark)
                .previewDevice("iPhone Air")

            KeyboardSetupView { }
                .preferredColorScheme(.dark)
                .previewDevice("iPad Pro (11-inch) (M4)")
        }
    }
}
#endif
