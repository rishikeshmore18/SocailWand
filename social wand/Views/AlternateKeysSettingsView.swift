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
    @State private var customNumericMap: [String: String] = [:]

    private let appGroupID = "group.com.rishimore.socialwand"
    private let storageKey = "CustomAlternateKeys"
    private let numericStorageKey = "CustomNumericAlternateKeys"
    private let row2Keys = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    private let row3Keys = ["z", "x", "c", "v", "b", "n", "m"]
    private let numericRow1Keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let numericRow2Keys = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
    private let numericRow3Keys = [".", ",", "?", "!", "'"]
    private let defaultMap: [String: String] = [
        "a": "@", "s": "!", "d": ":", "f": ";", "g": "(",
        "h": ")", "j": "&", "k": "\"", "l": "-",
        "z": ".", "x": ",", "c": "?", "v": "/", "b": "'",
        "n": "%", "m": "#"
    ]
    private let defaultNumericMap: [String: String] = [
        "1": "[", "2": "]", "3": "{", "4": "}", "5": "#",
        "6": "%", "7": "^", "8": "*", "9": "+", "0": "=",
        "-": "_", "/": "\\", ":": "|", ";": "~", "(": "<",
        ")": ">", "$": "€", "&": "£", "@": "¥", "\"": ".",
        "“": ".", "”": ".",
        ".": ":", ",": ";", "?": "/", "!": "\\", "'": "\"",
        "‘": "\"", "’": "\""
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
                        sectionView(title: "Row 2 (A–L)", keys: row2Keys, map: $customMap, defaultMap: defaultMap, saveAction: saveCustomMap)
                        sectionView(title: "Row 3 (Z–M)", keys: row3Keys, map: $customMap, defaultMap: defaultMap, saveAction: saveCustomMap)
                        sectionView(title: "123 Row 1 (1–0)", keys: numericRow1Keys, map: $customNumericMap, defaultMap: defaultNumericMap, saveAction: saveNumericCustomMap)
                        sectionView(title: "123 Row 2 (Symbols)", keys: numericRow2Keys, map: $customNumericMap, defaultMap: defaultNumericMap, saveAction: saveNumericCustomMap)
                        sectionView(title: "123 Row 3 (Punctuation)", keys: numericRow3Keys, map: $customNumericMap, defaultMap: defaultNumericMap, saveAction: saveNumericCustomMap)
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
            loadNumericCustomMap()
            withAnimation(.easeOut(duration: 0.35)) {
                showContent = true
            }
        }
    }

    private func sectionView(
        title: String,
        keys: [String],
        map: Binding<[String: String]>,
        defaultMap: [String: String],
        saveAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppBrand.textSecondary)

            VStack(spacing: 12) {
                ForEach(keys, id: \.self) { key in
                    keyRow(for: key, map: map, defaultMap: defaultMap, saveAction: saveAction)
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

    private func keyRow(
        for key: String,
        map: Binding<[String: String]>,
        defaultMap: [String: String],
        saveAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(key.uppercased())
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppBrand.textPrimary)
                .frame(width: 24, alignment: .leading)

            TextField("", text: binding(for: key, map: map, saveAction: saveAction), prompt: Text(defaultMap[key] ?? ""))
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

    private func binding(
        for key: String,
        map: Binding<[String: String]>,
        saveAction: @escaping () -> Void
    ) -> Binding<String> {
        Binding(
            get: { map.wrappedValue[key] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = trimmed.isEmpty ? "" : String(trimmed.prefix(1))
                map.wrappedValue[key] = value
                saveAction()
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

    private func loadNumericCustomMap() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let stored = defaults.dictionary(forKey: numericStorageKey) as? [String: String] ?? [:]
        var filtered: [String: String] = [:]
        let allowed = Set(numericRow1Keys + numericRow2Keys + numericRow3Keys)
        for (key, value) in stored {
            let lowerKey = key.lowercased()
            guard allowed.contains(lowerKey) else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            filtered[lowerKey] = String(trimmed.prefix(1))
        }
        customNumericMap = filtered
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

    private func saveNumericCustomMap() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var sanitized: [String: String] = [:]
        for (key, value) in customNumericMap {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            sanitized[key.lowercased()] = String(trimmed.prefix(1))
        }
        defaults.set(sanitized, forKey: numericStorageKey)
    }
}

#Preview {
    NavigationStack {
        AlternateKeysSettingsView()
    }
}
