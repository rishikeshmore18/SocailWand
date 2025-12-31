//
//  SuggestionsView.swift
//  SocialWandKeyboard
//

import SwiftUI
import UIKit

struct SuggestionsView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: SuggestionsViewModel
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedSuggestionIndex: Int? = nil
    
    // ✅ NEW: Dropdown states
    @State private var showToneDropdown: Bool = false
    @State private var showLengthDropdown: Bool = false
    @State private var showBlurOverlay: Bool = false
    
    // ✅ NEW: Local editing state (syncs with viewModel)
    @State private var selectedToneIDs: Set<String> = []
    @State private var selectedLengthID: String? = nil
    
    // ✅ NEW: Track original state to prevent unnecessary regeneration
    @State private var originalToneIDs: Set<String> = []
    @State private var originalLengthID: String? = nil
    
    // ✅ NEW: Constants
    private let maxToneSelections = 3
    private let appGroupID = "group.rishi-more.social-wand"
    
    // ✅ NEW: Tone options (same as TonePickerView)
    private let tones: [ToneOption] = [
        ToneOption(id: "assertive", title: "Assertive", emoji: "💪", isComingSoon: false),
        ToneOption(id: "confident", title: "Confident", emoji: "😎", isComingSoon: false),
        ToneOption(id: "playful", title: "Playful", emoji: "😜", isComingSoon: false),
        ToneOption(id: "empathetic", title: "Empathetic", emoji: "😌", isComingSoon: false),
        ToneOption(id: "flirtatious", title: "Flirtatious", emoji: "💋", isComingSoon: false),
        ToneOption(id: "professional", title: "Professional", emoji: "💼", isComingSoon: false),
        ToneOption(id: "casual", title: "Casual", emoji: "🤙", isComingSoon: false)
    ]
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.state.isLoading {
                        loadingView
                            .padding(.top, 80)
                    } else {
                        switch viewModel.state {
                        case .success:
                            successView
                        case .error(let message):
                            errorView(message: message)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            
            // ✅ NEW: Blur overlay
            if showBlurOverlay {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            let tonesChanged = showToneDropdown && selectedToneIDs != originalToneIDs
                            let lengthChanged = showLengthDropdown && selectedLengthID != originalLengthID
                            
                            showToneDropdown = false
                            showLengthDropdown = false
                            showBlurOverlay = false
                            
                            if tonesChanged || lengthChanged {
                                regenerateWithCurrentPreferences()
                            }
                        }
                    }
                    .zIndex(99)
            }
            
            // ✅ Tone Dropdown - positioned at top right area
            if showToneDropdown {
                VStack {
                    HStack {
                        Spacer()
                        toneDropdownMenu
                            .padding(.trailing, 80) // Approximate position near Tones chip
                    }
                    .padding(.top, 52) // Below header (16 top padding + 36 chip height)
                    Spacer()
                }
                .zIndex(200)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // ✅ Length Dropdown - positioned at top right edge
            if showLengthDropdown {
                VStack {
                    HStack {
                        Spacer()
                        lengthDropdownMenu
                            .padding(.trailing, 16) // Near right edge where Length chip is
                    }
                    .padding(.top, 52) // Below header
                    Spacer()
                }
                .zIndex(200)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
        }
        .onAppear {
            // Sync local state with viewModel
            selectedToneIDs = Set(viewModel.currentTones)
            selectedLengthID = viewModel.currentLength
        }
        .onChange(of: viewModel.currentTones) { oldValue, newValue in
            selectedToneIDs = Set(newValue)
        }
        .onChange(of: viewModel.currentLength) { oldValue, newValue in
            selectedLengthID = newValue
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "8B5CF6"))
            
            Text(loadingText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var loadingText: String {
        switch viewModel.state {
        case .loading:
            return "Generating suggestions..."
        case .loadingMore:
            return "Generating more..."
        default:
            return "Loading..."
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 12) {
            headerView
                .padding(.top, 16)
                .padding(.horizontal, 16)
            
            ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                // Separator before each new batch (every 2 suggestions after first pair)
                if index % 2 == 0 && index > 0 {
                    batchSeparator
                        .padding(.vertical, 12)
                }
                
                suggestionCard(
                    text: suggestion.text,
                    badge: index % 2 == 0 ? "Safe" : "Bold",
                    badgeColor: index % 2 == 0 ? .green : Color(hex: "8B5CF6"),
                    index: index
                )
            }
            
            generateMoreButton
                .padding(.vertical, 12)
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 6) {  // ✅ Reduced from 8 to 6
            // Left: Title + New badge (more compact)
            Text("Suggestions")
                .font(.system(size: 16, weight: .bold))  // ✅ Reduced from 18 to 16
                .lineLimit(1)
                .minimumScaleFactor(0.8)  // ✅ Allow text to shrink if needed
            
            if viewModel.suggestions.count > 2 {
                HStack(spacing: 3) {  // ✅ Reduced from 4 to 3
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))  // ✅ Reduced from 12 to 10
                        .foregroundColor(Color(hex: "8B5CF6"))
                    
                    Text("New")
                        .font(.system(size: 11, weight: .semibold))  // ✅ Reduced from 13 to 11
                        .foregroundColor(Color(hex: "8B5CF6"))
                }
                .padding(.horizontal, 8)  // ✅ Reduced from 10 to 8
                .padding(.vertical, 3)  // ✅ Reduced from 4 to 3
                .background(
                    RoundedRectangle(cornerRadius: 8)  // ✅ Reduced from 10 to 8
                        .fill(Color(hex: "8B5CF6").opacity(0.1))
                )
            }
            
            Spacer(minLength: 4)  // ✅ Minimum spacing to prevent complete collapse
            
            // Right: Preference chips (more compact)
            toneChip
            lengthChip
        }
    }
    
    private func suggestionCard(text: String, badge: String, badgeColor: Color, index: Int) -> some View {
        let isSelected = selectedSuggestionIndex == index
        
        return ZStack {
            // Main card content
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    if selectedSuggestionIndex == index {
                        // Deselect if tapping the same card
                        selectedSuggestionIndex = nil
                    } else {
                        // Select this card
                        selectedSuggestionIndex = index
                    }
                }
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    // Badge
                    HStack {
                        Text(badge)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(badgeColor)
                            .cornerRadius(8)
                        Spacer()
                    }
                    
                    // Text
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .blur(radius: isSelected ? 2 : 0)  // ✅ NEW: Blur content when selected
                .animation(.easeInOut(duration: 0.2), value: isSelected)  // ✅ NEW: Smooth blur transition
                .padding(16)
                .background(cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: "8B5CF6") : Color.clear, lineWidth: 2)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // ✅ NEW: Centered Apply button overlay (only shows when selected)
            if isSelected {
                Button(action: {
                    viewModel.onApply?(text)
                    
                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Apply")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            // Blur background
                            BlurView(style: colorScheme == .dark ? .dark : .light)
                            
                            // Purple gradient overlay
                            LinearGradient(
                                colors: [
                                    Color(hex: "8B5CF6").opacity(0.9),
                                    Color(hex: "7C3AED").opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                }
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(true)  // ✅ NEW: Ensure button is clickable
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)  // ✅ NEW: Smooth animation
        .padding(.horizontal, 16)
    }
    
    private var generateMoreButton: some View {
        Button(action: { viewModel.onGenerateMore?() }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                Text("Generate More")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(Color(hex: "8B5CF6"))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "8B5CF6"), lineWidth: 2)
            )
        }
    }
    
    private var batchSeparator: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.system(size: 20, weight: .bold))
            
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { viewModel.onRetry?() }) {  // ✅ CHANGED from onGenerateMore
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "8B5CF6"))
                .cornerRadius(24)
            }
        }
        .padding(.top, 80)
    }
    
    // MARK: - Adaptive Colors
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : .white
    }
    
    // MARK: - Preference Chips
    
    @ViewBuilder
    private var toneChip: some View {
        if !selectedToneIDs.isEmpty {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showToneDropdown.toggle()
                    showBlurOverlay = showToneDropdown
                    if showToneDropdown {
                        showLengthDropdown = false
                        originalToneIDs = selectedToneIDs
                    }
                }
                triggerHaptic(style: .light)
            }) {
                HStack(spacing: 3) {  // ✅ Reduced from 4 to 3
                    Text("\(selectedToneIDs.count)/\(maxToneSelections) Tone")  // ✅ Added "Tone" label
                        .font(.system(size: 11, weight: .semibold))  // ✅ Reduced from 13 to 11
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))  // ✅ Reduced from 10 to 9
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 8)  // ✅ Reduced from 12 to 8
                .padding(.vertical, 4)  // ✅ Reduced from 6 to 4
                .background(
                    LinearGradient(
                        colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)  // ✅ Reduced from 16 to 12
            }
        } else {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showToneDropdown.toggle()
                    showBlurOverlay = showToneDropdown
                    if showToneDropdown {
                        showLengthDropdown = false
                        originalToneIDs = selectedToneIDs
                    }
                }
                triggerHaptic(style: .light)
            }) {
                HStack(spacing: 3) {  // ✅ Reduced from 4 to 3
                    Text("Tones")
                        .font(.system(size: 11, weight: .medium))  // ✅ Reduced from 13 to 11
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))  // ✅ Reduced from 10 to 9
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)  // ✅ Reduced from 10 to 8
                .padding(.vertical, 4)  // ✅ Reduced from 6 to 4
                .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                .cornerRadius(12)  // ✅ Reduced from 16 to 12
            }
        }
    }
    
    @ViewBuilder
    private var lengthChip: some View {
        if let length = selectedLengthID {
            HStack(spacing: 4) {  // ✅ Reduced from 6 to 4
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showLengthDropdown.toggle()
                        showBlurOverlay = showLengthDropdown
                        if showLengthDropdown {
                            showToneDropdown = false
                            originalLengthID = selectedLengthID
                        }
                    }
                    triggerHaptic(style: .light)
                }) {
                    Text(length.capitalized)
                        .font(.system(size: 11, weight: .semibold))  // ✅ Reduced from 13 to 11
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.leading, 8)  // ✅ Reduced from 12 to 8
                        .padding(.vertical, 4)  // ✅ Reduced from 6 to 4
                }
                
                Button(action: {
                    clearLength()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))  // ✅ Reduced from 14 to 12
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.trailing, 8)  // ✅ Reduced from 12 to 8
                        .padding(.vertical, 4)  // ✅ Reduced from 6 to 4
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)  // ✅ Reduced from 16 to 12
        } else {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showLengthDropdown.toggle()
                    showBlurOverlay = showLengthDropdown
                    if showLengthDropdown {
                        showToneDropdown = false
                        originalLengthID = selectedLengthID
                    }
                }
                triggerHaptic(style: .light)
            }) {
                HStack(spacing: 3) {  // ✅ Reduced from 4 to 3
                    Text("Length")
                        .font(.system(size: 11, weight: .medium))  // ✅ Reduced from 13 to 11
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))  // ✅ Reduced from 10 to 9
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)  // ✅ Reduced from 10 to 8
                .padding(.vertical, 4)  // ✅ Reduced from 6 to 4
                .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                .cornerRadius(12)  // ✅ Reduced from 16 to 12
            }
        }
    }
    
    // MARK: - Dropdown Menus
    
    @ViewBuilder
    private var toneDropdownMenu: some View {
        VStack(spacing: 0) {
            // X Close Button
            HStack {
                Text("\(selectedToneIDs.count)/\(maxToneSelections) selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
                
                Spacer()
                
                Button(action: {
                    let changed = selectedToneIDs != originalToneIDs
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showToneDropdown = false
                        showBlurOverlay = false
                    }
                    triggerHaptic(style: .light)
                    
                    if changed {
                        regenerateWithCurrentPreferences()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            
            Divider()
            
            // Scrollable Tone Options
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tones) { tone in
                        Button(action: {
                            handleToneToggle(tone)
                        }) {
                            HStack(spacing: 8) {
                                Text(tone.emoji)
                                    .font(.system(size: 16))
                                
                                Text(tone.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedToneIDs.contains(tone.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "8B5CF6"))
                                } else if selectedToneIDs.count >= maxToneSelections {
                                    Image(systemName: "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary.opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                selectedToneIDs.contains(tone.id)
                                    ? Color(hex: "8B5CF6").opacity(0.1)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!selectedToneIDs.contains(tone.id) && selectedToneIDs.count >= maxToneSelections)
                        .opacity((!selectedToneIDs.contains(tone.id) && selectedToneIDs.count >= maxToneSelections) ? 0.5 : 1)
                        
                        if tone.id != tones.last?.id {
                            Divider()
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
        )
        .frame(width: 200)
    }
    
    @ViewBuilder
    private var lengthDropdownMenu: some View {
        VStack(spacing: 0) {
            // X Close Button
            HStack {
                Spacer()
                Button(action: {
                    let changed = selectedLengthID != originalLengthID
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showLengthDropdown = false
                        showBlurOverlay = false
                    }
                    triggerHaptic(style: .light)
                    
                    if changed {
                        regenerateWithCurrentPreferences()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            
            Divider()
            
            // Length Options
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
                        
                        if selectedLengthID == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "8B5CF6"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        selectedLengthID == option.id
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
    }
    
    // MARK: - Handlers
    
    private func handleToneToggle(_ tone: ToneOption) {
        triggerHaptic(style: .light)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if selectedToneIDs.contains(tone.id) {
                selectedToneIDs.remove(tone.id)
            } else if selectedToneIDs.count < maxToneSelections {
                selectedToneIDs.insert(tone.id)
            } else {
                triggerHaptic(style: .rigid)
                return
            }
        }
        
        // ✅ ONLY SAVE - do not regenerate yet
        saveTonesToAppGroup()
    }
    
    private func saveTonesToAppGroup() {
        let toneIDs = Array(selectedToneIDs)
        
        // Save to App Group
        if let defaults = UserDefaults(suiteName: appGroupID) {
            if toneIDs.isEmpty {
                defaults.removeObject(forKey: "SavedTonePreferences")
            } else {
                defaults.set(toneIDs, forKey: "SavedTonePreferences")
            }
            defaults.synchronize()
        }
        
        // Update viewModel (but don't trigger callback)
        viewModel.currentTones = toneIDs
    }
    
    private func selectLength(_ lengthID: String) {
        selectedLengthID = lengthID
        
        // Close dropdown
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showLengthDropdown = false
            showBlurOverlay = false
        }
        
        triggerHaptic(style: .medium)
        
        // Save and regenerate
        saveLengthAndRegenerate()
    }
    
    private func clearLength() {
        selectedLengthID = nil
        
        triggerHaptic(style: .light)
        
        // Save and regenerate
        saveLengthAndRegenerate()
    }
    
    private func regenerateWithCurrentPreferences() {
        // Trigger regeneration with current preferences
        viewModel.onPreferencesChanged?(Array(selectedToneIDs), selectedLengthID)
    }
    
    private func saveLengthAndRegenerate() {
        // Save to App Group
        if let defaults = UserDefaults(suiteName: appGroupID) {
            if let length = selectedLengthID {
                defaults.set(length, forKey: "SavedLengthPreference")
            } else {
                defaults.removeObject(forKey: "SavedLengthPreference")
            }
            defaults.synchronize()
        }
        
        // Update viewModel
        viewModel.currentLength = selectedLengthID
        
        // Trigger regeneration
        viewModel.onPreferencesChanged?(Array(selectedToneIDs), selectedLengthID)
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - BlurView Helper

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

