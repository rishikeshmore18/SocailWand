//
//  ImprovementSelectionView.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ImprovementSelectionView: View {
    let onComplete: ([ImprovementOption]) -> Void

        @State private var selectedIDs: Set<String> = []
    @State private var showContent = false

    private let options: [ImprovementOption] = [
        ImprovementOption(id: "reply", title: "Reply game", subtitle: "Keep convos engaging", emoji: "💬"),
        ImprovementOption(id: "starting", title: "Starting convos", subtitle: "Get to know people", emoji: "📝"),
        ImprovementOption(id: "emotions", title: "Reading emotions", subtitle: "Understand people better", emoji: "😔")
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
            let headlineSize = headlineFontSize(for: breakpoint)
            let headlineHeight = headlineSize * headlineLineHeightMultiplier(for: breakpoint)
            let cardSpacing = cardSpacing(for: breakpoint)
            let metrics = ImprovementCardMetrics.metrics(for: breakpoint)

            let cardsAvailable = max(available - logoSize - headlineHeight - heroSpacing * 3, 0)
            let rawHeightSum = cardsAvailable - CGFloat(options.count - 1) * cardSpacing
            let idealCardHeight = rawHeightSum / CGFloat(options.count)
            let clampedCardHeight = min(max(idealCardHeight, metrics.minHeight), metrics.maxHeight)
            let cardsStackHeight = clampedCardHeight * CGFloat(options.count) + cardSpacing * CGFloat(options.count - 1)

            VStack(spacing: heroSpacing) {
                Spacer(minLength: 0)

                VStack(spacing: heroSpacing) {
                    Image("SocialWandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSize, height: logoSize)
                        .shadow(color: Color.white.opacity(0.08), radius: 12, y: 6)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                        .accessibilityHidden(true)

                    Text("Which needs improving?")
                        .font(.system(size: headlineSize, weight: .bold, design: .rounded))
                        .foregroundStyle(AppBrand.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)

                    cardsStack(cardHeight: clampedCardHeight,
                               spacing: cardSpacing,
                               metrics: metrics)
                        .frame(height: cardsStackHeight)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 12)
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
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.1)) {
                showContent = true
            }
        }
    }

    private func cardsStack(cardHeight: CGFloat,
                             spacing: CGFloat,
                             metrics: ImprovementCardMetrics) -> some View {
        VStack(spacing: spacing) {
            ForEach(options) { option in
                ImprovementCard(option: option,
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
        .buttonStyle(PurpleCTAButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .padding(.horizontal, sidePadding)
        .padding(.top, ctaSpacing)
        .padding(.bottom, bottomPadding)
        .background(Color.black.opacity(0.92).ignoresSafeArea())
        .accessibilityHint(isEnabled ? "Continue to trait selection" : "Select at least one improvement to continue")
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

// MARK: - Card View

private struct ImprovementCard: View {
    let option: ImprovementOption
    let metrics: ImprovementCardMetrics
    let height: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: metrics.innerSpacing) {
                HStack(spacing: metrics.titleSpacing) {
                    Spacer(minLength: 0)

                    Text(option.title)
                        .font(.system(size: metrics.titleFont, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(option.emoji)
                        .font(.system(size: metrics.emojiFont))
                        .accessibilityHidden(true)

                    Spacer(minLength: 0)
                }

                Text(option.subtitle)
                    .font(.system(size: metrics.subtitleFont, weight: .regular, design: .rounded))
                    .foregroundStyle(AppBrand.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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
        .accessibilityLabel(Text("\(option.title). \(option.subtitle)"))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(AppBrand.cardBackground.opacity(isSelected ? 0.68 : 0.45))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .strokeBorder(isSelected ? AppBrand.purple : AppBrand.cardBorder, lineWidth: isSelected ? metrics.borderWidth : 1)
            .shadow(color: isSelected ? AppBrand.purple.opacity(0.30) : .clear, radius: 12, y: 6)
    }
}

// MARK: - Metrics

private struct ImprovementCardMetrics {
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let titleFont: CGFloat
    let subtitleFont: CGFloat
    let emojiFont: CGFloat
    let titleSpacing: CGFloat
    let innerSpacing: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat

    static func metrics(for breakpoint: LayoutBreakpoint) -> ImprovementCardMetrics {
        switch breakpoint {
        case .veryCompact:
            return ImprovementCardMetrics(
                minHeight: 58,
                maxHeight: 86,
                horizontalPadding: 16,
                verticalPadding: 12,
                titleFont: 18,
                subtitleFont: 14,
                emojiFont: 22,
                titleSpacing: 8,
                innerSpacing: 6,
                cornerRadius: 18,
                borderWidth: 2
            )
        case .compact:
            return ImprovementCardMetrics(
                minHeight: 66,
                maxHeight: 92,
                horizontalPadding: 18,
                verticalPadding: 14,
                titleFont: 20,
                subtitleFont: 15,
                emojiFont: 24,
                titleSpacing: 10,
                innerSpacing: 8,
                cornerRadius: 20,
                borderWidth: 2.5
            )
        case .regular:
            return ImprovementCardMetrics(
                minHeight: 72,
                maxHeight: 104,
                horizontalPadding: 20,
                verticalPadding: 16,
                titleFont: 22,
                subtitleFont: 16,
                emojiFont: 26,
                titleSpacing: 12,
                innerSpacing: 10,
                cornerRadius: 22,
                borderWidth: 3
            )
        }
    }
}

// MARK: - Helpers

private extension ImprovementSelectionView {
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
            return 1.24
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
            return 360
        case .compact:
            return 440
        case .regular:
            return 500
        }
    }
}

// MARK: - Models

struct ImprovementOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let emoji: String
}

// MARK: - Preview

#if DEBUG
struct ImprovementSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ImprovementSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDevice("iPhone SE (3rd generation)")

            ImprovementSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDevice("iPhone 17 Pro")

            ImprovementSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDevice("iPhone Air")

            ImprovementSelectionView { _ in }
                .preferredColorScheme(.dark)
                .previewDevice("iPad Pro (11-inch) (M4)")
        }
    }
}
#endif
