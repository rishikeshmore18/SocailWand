//
//  TranslatePickerView.swift
//  SocialWandKeyboard
//

import SwiftUI

struct TranslatePickerView: View {
    let onSelect: (TranslateLanguage) -> Void
    let onCancel: () -> Void

    @State private var recentLanguageIDs: [String] = []
    @Environment(\.colorScheme) var colorScheme

    private let appGroupID = "group.com.rishimore.socialwand"
    private let recentKey = "TranslateRecentLanguages"

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var sortedLanguages: [TranslateLanguage] {
        TranslateLanguageCatalog.languages.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var recentLanguages: [TranslateLanguage] {
        recentLanguageIDs.compactMap { TranslateLanguageCatalog.language(for: $0) }
    }

    var body: some View {
        GeometryReader { geometry in
            let breakpoint = KeyboardBreakpoint.from(height: geometry.size.height)
            let metrics = TranslateCardMetrics.metrics(for: breakpoint)

            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(metrics: metrics)

                    ScrollView {
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                            if !recentLanguages.isEmpty {
                                recentSection(metrics: metrics)
                            }

                            LazyVGrid(columns: columns, spacing: metrics.cardSpacing) {
                                ForEach(sortedLanguages) { language in
                                    TranslateCard(
                                        language: language,
                                        metrics: metrics
                                    ) {
                                        handleSelection(language)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.contentTopPadding)
                        .padding(.bottom, 120)
                    }
                }
            }
            .onAppear {
                loadRecents()
            }
        }
    }

    private func header(metrics: TranslateCardMetrics) -> some View {
        HStack(spacing: 8) {
            Text("Translate to:")
                .font(.system(size: metrics.headerFont, weight: .bold))
                .foregroundColor(.primary)

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
        .background(backgroundColor.opacity(0.95))
    }

    private func recentSection(metrics: TranslateCardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.system(size: metrics.subtitleFont, weight: .semibold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: metrics.cardSpacing) {
                ForEach(recentLanguages) { language in
                    TranslateCard(
                        language: language,
                        metrics: metrics
                    ) {
                        handleSelection(language)
                    }
                }
            }
        }
    }

    private func handleSelection(_ language: TranslateLanguage) {
        saveRecent(language)
        onSelect(language)
    }

    private func saveRecent(_ language: TranslateLanguage) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        var updated = recentLanguageIDs.filter { $0 != language.id }
        updated.insert(language.id, at: 0)
        if updated.count > 3 {
            updated = Array(updated.prefix(3))
        }

        recentLanguageIDs = updated
        defaults.set(updated, forKey: recentKey)
    }

    private func loadRecents() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        recentLanguageIDs = defaults.stringArray(forKey: recentKey) ?? []
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
}

private struct TranslateCard: View {
    let language: TranslateLanguage
    let metrics: TranslateCardMetrics
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: metrics.flagFont))

                Text(language.name)
                    .font(.system(size: metrics.titleFont, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
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
                Color.gray.opacity(0.3),
                lineWidth: 1.2
            )
    }
}

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

private struct TranslateCardMetrics {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cardSpacing: CGFloat
    let titleFont: CGFloat
    let subtitleFont: CGFloat
    let flagFont: CGFloat
    let headerFont: CGFloat
    let cornerRadius: CGFloat
    let contentTopPadding: CGFloat
    let sectionSpacing: CGFloat

    static func metrics(for breakpoint: KeyboardBreakpoint) -> TranslateCardMetrics {
        switch breakpoint {
        case .small:
            return TranslateCardMetrics(
                horizontalPadding: 12,
                verticalPadding: 10,
                cardSpacing: 10,
                titleFont: 14,
                subtitleFont: 12,
                flagFont: 16,
                headerFont: 18,
                cornerRadius: 14,
                contentTopPadding: 8,
                sectionSpacing: 16
            )
        case .medium:
            return TranslateCardMetrics(
                horizontalPadding: 14,
                verticalPadding: 12,
                cardSpacing: 12,
                titleFont: 15,
                subtitleFont: 13,
                flagFont: 18,
                headerFont: 20,
                cornerRadius: 16,
                contentTopPadding: 12,
                sectionSpacing: 18
            )
        case .large:
            return TranslateCardMetrics(
                horizontalPadding: 16,
                verticalPadding: 14,
                cardSpacing: 14,
                titleFont: 16,
                subtitleFont: 14,
                flagFont: 20,
                headerFont: 22,
                cornerRadius: 18,
                contentTopPadding: 16,
                sectionSpacing: 20
            )
        }
    }
}
