//
//  TraitsSelectionView.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TraitOption: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
}

struct TraitsSelectionView: View {
    let onComplete: (_ selected: [TraitOption]) -> Void

        @State private var selectedIDs: Set<String> = []

    private let options: [TraitOption] = [
        TraitOption(id: "assertive", title: "Assertive", emoji: "💪"),
        TraitOption(id: "confident", title: "Confident", emoji: "😎"),
        TraitOption(id: "playful", title: "Playful", emoji: "🤪"),
        TraitOption(id: "empathetic", title: "Empathetic", emoji: "😔"),
        TraitOption(id: "flirtatious", title: "Flirtatious", emoji: "💦")
    ]

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
            let bottomPadding = bottomPadding(for: breakpoint, safeInsets: safeInsets)
            let available = max(safeHeight - headerTop - ctaHeight - ctaSpacing - bottomPadding,
                               minHeroHeight(for: breakpoint))

            let logoSize = logoSize(for: breakpoint)
            let heroSpacing = heroSpacing(for: breakpoint)
            let headlineFontSize = headlineFontSize(for: breakpoint)
            let estimatedHeadlineHeight = headlineFontSize * headlineLineHeightMultiplier(for: breakpoint)
            let cardSpacing = cardSpacing(for: breakpoint)
            let metrics = TraitCardMetrics.metrics(for: breakpoint)

            let cardsAvailable = max(available - logoSize - estimatedHeadlineHeight - heroSpacing * 3, 0)
            let rawCardHeightSum = cardsAvailable - CGFloat(options.count - 1) * cardSpacing
            let idealCardHeight = rawCardHeightSum / CGFloat(options.count)
            let clampedCardHeight = min(max(idealCardHeight, metrics.minHeight), metrics.maxHeight)
            let minimumStackHeight = metrics.minHeight * CGFloat(options.count) + cardSpacing * CGFloat(options.count - 1)
            let cardsStackHeight = clampedCardHeight * CGFloat(options.count) + cardSpacing * CGFloat(options.count - 1)
            let requiresScroll = false
            let scrollFrameHeight = max(min(cardsAvailable, cardsStackHeight), minimumStackHeight)

            VStack(spacing: heroSpacing) {
                Spacer(minLength: 0)

                VStack(spacing: heroSpacing) {
                    Image("SocialWandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSize, height: logoSize)
                        .shadow(color: Color.white.opacity(0.08), radius: 12, y: 6)
                        .accessibilityHidden(true)

                    Text("I want to become more…")
                        .font(.system(size: headlineFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .accessibilityAddTraits(.isHeader)

                    Group {
                        if requiresScroll {
                            ScrollView(showsIndicators: false) {
                                cardsStack(cardHeight: metrics.minHeight,
                                           spacing: cardSpacing,
                                           metrics: metrics)
                                    .padding(.vertical, cardSpacing / 2)
                            }
                            .frame(maxHeight: scrollFrameHeight)
                        } else {
                            cardsStack(cardHeight: clampedCardHeight,
                                       spacing: cardSpacing,
                                       metrics: metrics)
                                .frame(height: cardsStackHeight)
                        }
                    }
                }
                .frame(maxWidth: heroMaxWidth(for: safeWidth))
                .frame(maxWidth: .infinity)
                .frame(maxHeight: available)
                .layoutPriority(1)

                Spacer(minLength: bottomSpacer(for: breakpoint, safeInsets: safeInsets))
            }
            .padding(.top, headerTop)
            .padding(.horizontal, sidePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                CTASection(ctaHeight: ctaHeight,
                           ctaFontSize: ctaFontSize(for: breakpoint),
                           ctaSpacing: ctaSpacing,
                           sidePadding: sidePadding,
                           bottomPadding: bottomPadding,
                           isEnabled: !selectedIDs.isEmpty,
                           action: submitSelection)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.black.ignoresSafeArea())
    }

    private func cardsStack(cardHeight: CGFloat,
                             spacing: CGFloat,
                             metrics: TraitCardMetrics) -> some View {
        VStack(spacing: spacing) {
            ForEach(options) { option in
                TraitCard(option: option,
                          metrics: metrics,
                          height: cardHeight,
                          isSelected: selectedIDs.contains(option.id)) {
                    toggleSelection(for: option.id)
                }
            }
        }
    }

    private func submitSelection() {
        guard !selectedIDs.isEmpty else { return }
        let ordered = options.filter { selectedIDs.contains($0.id) }
        onComplete(ordered)
    }

    private func toggleSelection(for id: String) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

// MARK: - CTA Section

private struct CTASection: View {
    let ctaHeight: CGFloat
    let ctaFontSize: CGFloat
    let ctaSpacing: CGFloat
    let sidePadding: CGFloat
    let bottomPadding: CGFloat
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Improve these 🙌")
                .font(.system(size: ctaFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: ctaHeight)
        }
        .buttonStyle(PrimaryCTAButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .padding(.horizontal, sidePadding)
        .padding(.top, ctaSpacing)
        .padding(.bottom, bottomPadding)
        .background(Color.black.opacity(0.92).ignoresSafeArea())
        .accessibilityHint(isEnabled ? "Completes trait selection" : "Select at least one trait to continue")
    }
}

private struct PrimaryCTAButtonStyle: ButtonStyle {
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

// MARK: - Card View

private struct TraitCard: View {
    let option: TraitOption
    let metrics: TraitCardMetrics
    let height: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.spacing) {
                Spacer(minLength: 0)

                Text(option.title)
                    .font(.system(size: metrics.titleFont, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(option.emoji)
                    .font(.system(size: metrics.emojiFont))
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.title))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(AppBrand.cardBackground.opacity(isSelected ? 0.65 : 0.45))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .strokeBorder(isSelected ? AppBrand.purple : Color.white.opacity(0.08), lineWidth: isSelected ? metrics.borderWidth : 1)
            .shadow(color: isSelected ? AppBrand.purple.opacity(0.30) : .clear, radius: 12, y: 6)
    }
}

// MARK: - Metrics

private struct TraitCardMetrics {
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let titleFont: CGFloat
    let emojiFont: CGFloat
    let spacing: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat

    static func metrics(for breakpoint: LayoutBreakpoint) -> TraitCardMetrics {
        switch breakpoint {
        case .veryCompact:
            return TraitCardMetrics(
                minHeight: 48,
                maxHeight: 72,
                horizontalPadding: 16,
                verticalPadding: 10,
                titleFont: 18,
                emojiFont: 22,
                spacing: 8,
                cornerRadius: 16,
                borderWidth: 2
            )
        case .compact:
            return TraitCardMetrics(
                minHeight: 56,
                maxHeight: 80,
                horizontalPadding: 18,
                verticalPadding: 12,
                titleFont: 20,
                emojiFont: 24,
                spacing: 10,
                cornerRadius: 20,
                borderWidth: 2.5
            )
        case .regular:
            return TraitCardMetrics(
                minHeight: 60,
                maxHeight: 92,
                horizontalPadding: 20,
                verticalPadding: 14,
                titleFont: 22,
                emojiFont: 26,
                spacing: 12,
                cornerRadius: 22,
                borderWidth: 3
            )
        }
    }
}

// MARK: - Helpers

private extension TraitsSelectionView {
    func horizontalPadding(forWidth width: CGFloat) -> CGFloat {
width < 340 ? 16 : (width < 420 ? 20 : 24)
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

    func heroMaxWidth(for width: CGFloat) -> CGFloat {
        min(width, 520)
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
            return 20
        case .compact:
            return 24
        case .regular:
            return 28
        }
    }

    func headlineLineHeightMultiplier(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 1.2
        case .compact, .regular:
            return 1.18
        }
    }

    func cardSpacing(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 10
        case .compact:
            return 12
        case .regular:
            return 14
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

    func minHeroHeight(for breakpoint: LayoutBreakpoint) -> CGFloat {
        switch breakpoint {
        case .veryCompact:
            return 360
        case .compact:
            return 440
        case .regular:
            return 500
        }
    }
}

private extension TraitsSelectionView {
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
}

// MARK: - Preview

struct TraitsSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TraitsSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDisplayName("iPhone SE")
                .previewDevice("iPhone SE (3rd generation)")

            TraitsSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDisplayName("iPhone 17 Pro")
                .previewDevice("iPhone 17 Pro")

            TraitsSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDisplayName("iPhone Air")
                .previewDevice("iPhone Air")

            TraitsSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDisplayName("iPad Pro 11")
                .previewDevice("iPad Pro (11-inch) (M4)")
        }
    }
}
