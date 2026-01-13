//
//  EmailComposeView.swift
//  social wand
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct EmailComposeView: View {
    enum EmailMode: String, CaseIterable {
        case write = "Write"
        case reply = "Reply"
    }

    enum ComposeState {
        case editing
        case generating
        case success([[String]])
    }

    @State private var mode: EmailMode = .write
    @State private var state: ComposeState = .editing

    @State private var writeText: String = ""
    @State private var incomingEmail: String = ""
    @State private var replyDraft: String = ""

    @State private var writeSelection = NSRange(location: 0, length: 0)
    @State private var incomingSelection = NSRange(location: 0, length: 0)
    @State private var replySelection = NSRange(location: 0, length: 0)

    @State private var selectedTones: [String] = []
    @State private var selectedLength: String? = nil
    @State private var showTonePicker = false
    @State private var showLengthPicker = false
    @State private var errorMessage: String?
    @State private var allGenerations: [[String]] = []

    @Environment(\.dismiss) private var dismiss

    private let toneMapping: [String: String] = [
        "assertive": "Assertive",
        "confident": "Confident",
        "playful": "Playful",
        "empathetic": "Empathetic",
        "flirtatious": "Flirtatious",
        "professional": "Professional",
        "casual": "Casual"
    ]

    private let lengthMapping: [String: String] = [
        "short": "Short",
        "medium": "Medium",
        "long": "Long"
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .editing:
                    editingView
                case .generating:
                    generatingView
                case .success(let generations):
                    GenerationSuccessView(
                        allGenerations: generations,
                        sourceApp: "Email",
                        onGenerateAnother: { regenerateEmail() },
                        onGoBack: { state = .editing },
                        onGoHome: { dismiss() }
                    )
                }
            }
            .navigationTitle("Email")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTonePicker) { tonePickerSheet }
            .sheet(isPresented: $showLengthPicker) { lengthPickerSheet }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if case .success = state {
                        EmptyView()
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                loadSavedPreferences()
            }
        }
    }

    private var editingView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    modePicker
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    VStack(spacing: 16) {
                        if mode == .write {
                            EmailTextField(
                                title: "Email to Rewrite",
                                text: $writeText,
                                selectedRange: $writeSelection,
                                placeholder: "Paste or write the email you want rewritten..."
                            )
                        } else {
                            EmailTextField(
                                title: "Email Received",
                                text: $incomingEmail,
                                selectedRange: $incomingSelection,
                                placeholder: "Paste the email you received..."
                            )

                            EmailTextField(
                                title: "Your Reply",
                                text: $replyDraft,
                                selectedRange: $replySelection,
                                placeholder: "Write the reply you want polished..."
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    preferenceButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    preferencesContainer
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }
                }
            }

            Spacer()

            Button(action: generateEmail) {
                Text("Generate")
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

    private var modePicker: some View {
        Picker("Email Mode", selection: $mode) {
            ForEach(EmailMode.allCases, id: \.self) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var preferenceButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showTonePicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform").font(.system(size: 14))
                    Text("Tone").font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "8B5CF6"))
                .cornerRadius(10)
            }

            Button(action: { showLengthPicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft").font(.system(size: 14))
                    Text("Length").font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "8B5CF6"))
                .cornerRadius(10)
            }

            Spacer()
        }
    }

    private var preferencesContainer: some View {
        let hasPreferences = !selectedTones.isEmpty || selectedLength != nil

        return VStack(alignment: .leading, spacing: 8) {
            Text("Selected Preferences:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            if hasPreferences {
                FlowLayout(spacing: 8) {
                    ForEach(selectedTones, id: \.self) { toneID in
                        PreferenceChip(
                            title: toneMapping[toneID] ?? toneID.capitalized,
                            onRemove: { removeTone(toneID) }
                        )
                    }

                    if let lengthID = selectedLength {
                        PreferenceChip(
                            title: lengthMapping[lengthID] ?? lengthID.capitalized,
                            onRemove: { removeLength() }
                        )
                    }
                }
            } else {
                Text("No preferences selected")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Writing your email...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            Text("This may take a few seconds")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var tonePickerSheet: some View {
        NavigationStack {
            TonePickerView(
                onApply: { _ in },
                onSave: { handleToneSave($0) },
                onCancel: { showTonePicker = false },
                onClear: { handleToneClear() },
                savedPreferences: selectedTones,
                hasTextContent: false,
                showDoneButton: true
            )
            .navigationTitle("Choose Tone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { showTonePicker = false }
                }
            }
        }
    }

    private var lengthPickerSheet: some View {
        NavigationStack {
            LengthPickerView(
                onApply: { _ in },
                onSave: { handleLengthSave($0) },
                onCancel: { showLengthPicker = false },
                onClear: { handleLengthClear() },
                savedPreference: selectedLength,
                hasTextContent: false,
                showDoneButton: true
            )
            .navigationTitle("Choose Length")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { showLengthPicker = false }
                }
            }
        }
    }

    private func loadSavedPreferences() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            return
        }

        if let savedTones = defaults.stringArray(forKey: "SavedTonePreferences"), !savedTones.isEmpty {
            selectedTones = savedTones
        }

        if let savedLength = defaults.string(forKey: "SavedLengthPreference") {
            selectedLength = savedLength
        }
    }

    private func handleToneSave(_ toneIDs: [String]) {
        selectedTones = toneIDs
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(toneIDs, forKey: "SavedTonePreferences")
        }
    }

    private func handleToneClear() {
        selectedTones = []
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.removeObject(forKey: "SavedTonePreferences")
        }
    }

    private func handleLengthSave(_ lengthID: String) {
        selectedLength = lengthID
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(lengthID, forKey: "SavedLengthPreference")
        }
    }

    private func handleLengthClear() {
        selectedLength = nil
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.removeObject(forKey: "SavedLengthPreference")
        }
    }

    private func removeTone(_ toneID: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedTones.removeAll { $0 == toneID }
        }

        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(selectedTones, forKey: "SavedTonePreferences")
        }
    }

    private func removeLength() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedLength = nil
        }

        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.removeObject(forKey: "SavedLengthPreference")
        }
    }

    private func generateEmail() {
        errorMessage = nil

        switch mode {
        case .write:
            guard let input = selectedTextOrFull(writeText, range: writeSelection), !input.isEmpty else {
                errorMessage = "Please enter the email you want rewritten."
                return
            }
        case .reply:
            guard let incoming = selectedTextOrFull(incomingEmail, range: incomingSelection), !incoming.isEmpty else {
                errorMessage = "Please provide the email you received."
                return
            }
        }

        state = .generating

        Task {
            do {
                let toneTitles = selectedTones.compactMap { toneMapping[$0] }
                let lengthTitle = selectedLength != nil
                    ? (selectedLength!.prefix(1).uppercased() + selectedLength!.dropFirst())
                    : "Medium"

                let previousOutputs = allGenerations.flatMap { $0 }
                let alternatives: [String]

                if mode == .write {
                    let input = selectedTextOrFull(writeText, range: writeSelection) ?? ""
                    alternatives = try await callEmailWriteAPI(
                        text: input,
                        tones: toneTitles,
                        length: lengthTitle,
                        previousOutputs: previousOutputs
                    )
                } else {
                    let incoming = selectedTextOrFull(incomingEmail, range: incomingSelection) ?? ""
                    let draft = selectedTextOrFull(replyDraft, range: replySelection) ?? ""
                    alternatives = try await callEmailReplyAPI(
                        incoming: incoming,
                        draft: draft,
                        tones: toneTitles,
                        length: lengthTitle,
                        previousOutputs: previousOutputs
                    )
                }

                await MainActor.run {
                    allGenerations.insert(alternatives, at: 0)
                    state = .success(allGenerations)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate: \(error.localizedDescription)"
                    state = .editing
                }
            }
        }
    }

    private func regenerateEmail() {
        generateEmail()
    }

    private func selectedTextOrFull(_ text: String, range: NSRange) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }

        if range.length > 0, let selected = substring(text, range: range) {
            let trimmedSelection = selected.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedSelection.isEmpty ? trimmedText : trimmedSelection
        }

        return trimmedText
    }

    private func substring(_ text: String, range: NSRange) -> String? {
        guard let textRange = Range(range, in: text) else { return nil }
        return String(text[textRange])
    }

    private func callEmailWriteAPI(
        text: String,
        tones: [String],
        length: String,
        previousOutputs: [String]
    ) async throws -> [String] {
        #if DEBUG
        let baseURL = "http://192.168.1.248:3000"
        #else
        let baseURL = "https://your-production-url.com"
        #endif

        guard let url = URL(string: "\(baseURL)/api/email/write") else {
            throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "tones": tones,
            "length": length,
            "previousOutputs": previousOutputs
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "API", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }

        return try parseAlternatives(from: data)
    }

    private func callEmailReplyAPI(
        incoming: String,
        draft: String,
        tones: [String],
        length: String,
        previousOutputs: [String]
    ) async throws -> [String] {
        #if DEBUG
        let baseURL = "http://192.168.1.248:3000"
        #else
        let baseURL = "https://your-production-url.com"
        #endif

        guard let url = URL(string: "\(baseURL)/api/email/reply") else {
            throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "incoming": incoming,
            "draft": draft,
            "tones": tones,
            "length": length,
            "previousOutputs": previousOutputs
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "API", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }

        return try parseAlternatives(from: data)
    }

    private func parseAlternatives(from data: Data) throws -> [String] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let alternatives = json?["alternatives"] as? [String], alternatives.count >= 2 {
            return Array(alternatives.prefix(2))
        }

        if let safe = json?["safe"] as? String, let bold = json?["bold"] as? String {
            return [safe, bold]
        }

        if let result = json?["result"] as? String {
            let parts = result.split(separator: "|").map { String($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count >= 2 {
                return Array(parts.prefix(2))
            }
            return [result, result]
        }

        throw NSError(domain: "API", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
}

private struct EmailTextField: View {
    let title: String
    @Binding var text: String
    @Binding var selectedRange: NSRange
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                SelectableTextView(text: $text, selectedRange: $selectedRange)
                    .frame(minHeight: 140)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

private struct SelectableTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textView.textColor = UIColor.label
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        let textLength = uiView.text.utf16.count
        let clampedLocation = min(max(0, selectedRange.location), textLength)
        let clampedLength = min(max(0, selectedRange.length), textLength - clampedLocation)
        let clampedRange = NSRange(location: clampedLocation, length: clampedLength)

        if uiView.selectedRange.location != clampedRange.location || uiView.selectedRange.length != clampedRange.length {
            uiView.selectedRange = clampedRange
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: SelectableTextView

        init(_ parent: SelectableTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}
