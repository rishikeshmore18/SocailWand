//
//  AlternateKeysSettingsView.swift
//  social wand
//

import SwiftUI
import UIKit

struct AlternateKeysSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var customMap: [String: String] = [:]

    private let appGroupID = "group.rishi-more.social-wand"
    private let storageKey = "CustomAlternateKeys"
    private let row2Keys = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    private let row3Keys = ["z", "x", "c", "v", "b", "n", "m"]
    private let defaultMap: [String: String] = [
        "a": "@", "s": "!", "d": ":", "f": ";", "g": "(",
        "h": ")", "j": "&", "k": "\"", "l": "-",
        "z": ".", "x": ",", "c": "?", "v": "/", "b": "'",
        "n": "%", "m": "#"
    ]

    var body: some View {
        GeometryReader { geo in
            let safeHeight = max(geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom, 1)
            let breakpoint = LayoutBreakpoint.forHeight(safeHeight)
            let horizontalPadding = max(CGFloat(20), geo.size.width * 0.05)

            VStack(spacing: 0) {
                Text("Alternate Keys")
                    .font(.system(size: breakpoint == .veryCompact ? 26 : (breakpoint == .compact ? 30 : 34), weight: .bold, design: .rounded))
                    .foregroundStyle(AppBrand.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)

                Text("Customize row 2 and row 3 only.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppBrand.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 6)

                ScrollView {
                    VStack(spacing: 16) {
                        sectionView(title: "Row 2 (A–L)", keys: row2Keys)
                        sectionView(title: "Row 3 (Z–M)", keys: row3Keys)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, horizontalPadding)
                }

                Spacer()
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(AppBrand.purple)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    saveCustomMap()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Text("Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppBrand.purple)
                }
            }
        }
        .onAppear {
            loadCustomMap()
            withAnimation(.easeOut(duration: 0.35)) {
                showContent = true
            }
        }
    }

    private func sectionView(title: String, keys: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppBrand.textSecondary)

            VStack(spacing: 12) {
                ForEach(keys, id: \.self) { key in
                    keyRow(for: key)
                }
            }
            .padding(12)
            .background(AppBrand.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppBrand.cardBorder, lineWidth: 1)
            )
            .cornerRadius(14)
        }
    }

    private func keyRow(for key: String) -> some View {
        HStack(spacing: 12) {
            Text(key.uppercased())
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppBrand.textPrimary)
                .frame(width: 24, alignment: .leading)

            TextField("", text: binding(for: key), prompt: Text(defaultMap[key] ?? ""))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .multilineTextAlignment(.center)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppBrand.textPrimary)
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(AppBrand.dim)
                .cornerRadius(10)

            Spacer()

            if let defaultValue = defaultMap[key] {
                Text("Default \(defaultValue)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppBrand.textSecondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { customMap[key] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = trimmed.isEmpty ? "" : String(trimmed.prefix(1))
                customMap[key] = value
                saveCustomMap()
            }
        )
    }

    private func loadCustomMap() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let stored = defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
        var filtered: [String: String] = [:]
        let allowed = Set(row2Keys + row3Keys)
        for (key, value) in stored {
            let lowerKey = key.lowercased()
            guard allowed.contains(lowerKey) else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            filtered[lowerKey] = String(trimmed.prefix(1))
        }
        customMap = filtered
    }

    private func saveCustomMap() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var sanitized: [String: String] = [:]
        for (key, value) in customMap {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            sanitized[key.lowercased()] = String(trimmed.prefix(1))
        }
        defaults.set(sanitized, forKey: storageKey)
    }
}

#Preview {
    NavigationStack {
        AlternateKeysSettingsView()
    }
}
