import SwiftUI

enum ToolbarButtonType {
    case upload, reply, rewrite, translate, email, tone, length, menu, save, clipboard, settings
}

struct WandToolbar: View {
    let onWandTap: () -> Void
    let onToneButtonTap: () -> Void
    let onLengthButtonTap: () -> Void  // ✅ NEW
    let onUploadButtonTap: () -> Void  // ✅ NEW
    let onReplyButtonTap: () -> Void
    let onRewriteButtonTap: () -> Void
    let onTranslateButtonTap: () -> Void
    let onEmailButtonTap: () -> Void
    let onMenuButtonTap: () -> Void  // ✅ NEW
    let onSaveButtonTap: (() -> Void)?  // ✅ NEW: Optional callback for Save action
    let onClipboardButtonTap: (() -> Void)?  // ✅ NEW: Optional callback for Clipboard action
    let onSettingsButtonTap: (() -> Void)?  // ✅ NEW: Optional callback for Settings action
    @ObservedObject var autocompleteModel: ToolbarAutocompleteModel
    let onAutocompleteTap: (String) -> Void
    let maxSuggestionsCount: Int
    let isSuggestionsVisible: () -> Bool
    let onCloseSuggestions: (() -> Void)?
    @State private var isExpanded = false
    @State private var isLastButtonVisible = false
    @State private var lastVisibleButtonIndex: Int = -1
    @State private var activeButton: ToolbarButtonType? = nil
    @Environment(\.colorScheme) var colorScheme
    
    init(onWandTap: @escaping () -> Void, onToneButtonTap: @escaping () -> Void, onLengthButtonTap: @escaping () -> Void, onUploadButtonTap: @escaping () -> Void, onReplyButtonTap: @escaping () -> Void, onRewriteButtonTap: @escaping () -> Void, onTranslateButtonTap: @escaping () -> Void, onEmailButtonTap: @escaping () -> Void, onMenuButtonTap: @escaping () -> Void, onSaveButtonTap: (() -> Void)? = nil, onClipboardButtonTap: (() -> Void)? = nil, onSettingsButtonTap: (() -> Void)? = nil, autocompleteModel: ToolbarAutocompleteModel, onAutocompleteTap: @escaping (String) -> Void, maxSuggestionsCount: Int, isSuggestionsVisible: @escaping () -> Bool, onCloseSuggestions: (() -> Void)?) {
        self.onWandTap = onWandTap
        self.onToneButtonTap = onToneButtonTap
        self.onLengthButtonTap = onLengthButtonTap
        self.onUploadButtonTap = onUploadButtonTap
        self.onReplyButtonTap = onReplyButtonTap
        self.onRewriteButtonTap = onRewriteButtonTap
        self.onTranslateButtonTap = onTranslateButtonTap
        self.onEmailButtonTap = onEmailButtonTap
        self.onMenuButtonTap = onMenuButtonTap
        self.onSaveButtonTap = onSaveButtonTap
        self.onClipboardButtonTap = onClipboardButtonTap
        self.onSettingsButtonTap = onSettingsButtonTap
        self.autocompleteModel = autocompleteModel
        self.onAutocompleteTap = onAutocompleteTap
        self.maxSuggestionsCount = maxSuggestionsCount
        self.isSuggestionsVisible = isSuggestionsVisible
        self.onCloseSuggestions = onCloseSuggestions
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // X button - FIXED on far left (doesn't scroll)
            Button(action: handleXButtonTap) {
                WandIcon(isExpanded: isExpanded)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())

            if !isExpanded && !autocompleteModel.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(autocompleteModel.suggestions.prefix(suggestionLimit), id: \.self) { suggestion in
                            Button(action: { onAutocompleteTap(suggestion) }) {
                                Text(suggestion)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(chipTextColor)
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(chipBackgroundColor)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.leading, 6)
                }
                .transition(.opacity)
            }
            
            if isExpanded {
                // Gap after X button
                Spacer()
                    .frame(width: 12)
                
                // Scrollable area with buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(toolbarButtons.enumerated()), id: \.offset) { index, button in
                            ToolbarButton(
                                icon: button.icon,
                                label: button.label,
                                isActive: activeButton == button.type,
                                action: {
                                    triggerHaptic()
                                    button.action()
                                }
                            )
                            .background(
                                GeometryReader { buttonGeometry in
                                    Color.clear.preference(
                                        key: ButtonVisibilityPreferenceKey.self,
                                        value: [ButtonVisibilityData(
                                            index: index,
                                            frame: buttonGeometry.frame(in: .named("scroll"))
                                        )]
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ButtonVisibilityPreferenceKey.self) { values in
                    handleButtonVisibility(values)
                }
                .mask(
                    // Dynamic gradient fade - hide when last button visible
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: isLastButtonVisible ? 1.0 : 0.85),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 44)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExpandToolbar"))) { _ in
            withAnimation(.spring(duration: 0.5)) {
                isExpanded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetActiveButton"))) { notification in
            if let buttonType = notification.userInfo?["buttonType"] as? ToolbarButtonType {
                setActiveButton(buttonType)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearActiveButton"))) { notification in
            if let buttonType = notification.userInfo?["buttonType"] as? ToolbarButtonType {
                if activeButton == buttonType {
                    clearActiveButton()
                }
            }
        }
    }
    
    // Toolbar button definitions
    private var toolbarButtons: [(icon: String, label: String, type: ToolbarButtonType, action: () -> Void)] {
        let appGroupID = "group.com.rishimore.socialwand"
        
        // ALL available buttons (including menu actions)
        let allButtons: [(id: String, icon: String, label: String, type: ToolbarButtonType, action: () -> Void)] = [
            ("upload", "photo.on.rectangle", "Upload Context", .upload, onUploadButtonTap),
            ("reply", "arrowshape.turn.up.left", "Reply", .reply, onReplyButtonTap),
            ("rewrite", "pencil.line", "Rewrite", .rewrite, onRewriteButtonTap),
            ("translate", "globe", "Translate", .translate, onTranslateButtonTap),
            ("email", "envelope", "Email", .email, onEmailButtonTap),
            ("tone", "waveform", "Tone", .tone, onToneButtonTap),
            ("length", "text.alignleft", "Length", .length, onLengthButtonTap),
            // ✅ NEW: Menu buttons (can now appear in toolbar if in positions 1-4)
            ("save", "square.and.arrow.down", "Save to Clipboard", .save, {
                // If callback provided, use it; otherwise open menu
                if let saveAction = onSaveButtonTap {
                    saveAction()
                } else {
                    onMenuButtonTap()
                }
            }),
            ("clipboard", "list.clipboard", "Clipboard", .clipboard, {
                if let clipboardAction = onClipboardButtonTap {
                    clipboardAction()
                } else {
                    onMenuButtonTap()
                }
            }),
            ("settings", "gearshape", "", .settings, {
                if let settingsAction = onSettingsButtonTap {
                    settingsAction()
                } else {
                    onMenuButtonTap()
                }
            })
        ]
        
        // Try to load saved order
        if let defaults = UserDefaults(suiteName: appGroupID),
           let savedOrder = defaults.stringArray(forKey: "ToolbarButtonOrder") {
            let storedCount = defaults.object(forKey: "ToolbarButtonCount") as? Int
            let toolbarCount = min(max(storedCount ?? 4, 0), allButtons.count)
            
            // Take configured number of buttons for toolbar (rest go to menu)
            let toolbarButtonIDs = Array(savedOrder.prefix(toolbarCount)).filter { $0 != "settings" }
            
            // Map IDs to button definitions
            var orderedButtons: [(icon: String, label: String, type: ToolbarButtonType, action: () -> Void)] = []
            
            for id in toolbarButtonIDs {
                if let button = allButtons.first(where: { $0.id == id }) {
                    orderedButtons.append((button.icon, button.label, button.type, button.action))
                }
            }
            
            // If less than toolbarCount buttons in saved order, fill with defaults
            if orderedButtons.count < toolbarCount {
                let existingIDs = Set(toolbarButtonIDs)
                let remainingButtons = allButtons.filter { !existingIDs.contains($0.id) }
                
                for button in remainingButtons.prefix(toolbarCount - orderedButtons.count) {
                    orderedButtons.append((button.icon, button.label, button.type, button.action))
                }
            }
            
            orderedButtons.append(("chevron.down", "Menu", .menu, onMenuButtonTap))
            orderedButtons.append(("gearshape", "", .settings, {
                if let settingsAction = onSettingsButtonTap {
                    settingsAction()
                } else {
                    onMenuButtonTap()
                }
            }))
            
            return orderedButtons
        }
        
        let storedCount = UserDefaults(suiteName: appGroupID)?.object(forKey: "ToolbarButtonCount") as? Int
        let toolbarCount = min(max(storedCount ?? 4, 0), allButtons.count)

        // No saved order - use first toolbarCount from allButtons + Menu
        let defaultToolbarButtons = Array(allButtons.prefix(toolbarCount))
        var buttons = defaultToolbarButtons.map { ($0.icon, $0.label, $0.type, $0.action) }
        buttons.append(("chevron.down", "Menu", .menu, onMenuButtonTap))
        buttons.append(("gearshape", "", .settings, {
            if let settingsAction = onSettingsButtonTap {
                settingsAction()
            } else {
                onMenuButtonTap()
            }
        }))
        return buttons
    }
    
    // Handle button visibility
    private func handleButtonVisibility(_ values: [ButtonVisibilityData]) {
        // Check if last button (Menu) is visible
        let lastButtonIndex = toolbarButtons.count - 1
        let isLastVisible = values.contains { data in
            data.index == lastButtonIndex && data.frame.maxX > 0
        }
        
        // Update fade state
        if isLastVisible != isLastButtonVisible {
            isLastButtonVisible = isLastVisible
        }
        
        // Haptic feedback for new button entering view
        guard let firstVisible = values.first(where: { data in
            data.frame.minX >= 0 && data.frame.minX < 300
        }) else { return }
        
        if firstVisible.index != lastVisibleButtonIndex {
            triggerScrollHaptic()
            lastVisibleButtonIndex = firstVisible.index
        }
    }
    
    private func handleXButtonTap() {
        triggerHaptic()
        
        if isSuggestionsVisible() {
            onCloseSuggestions?()   // hide suggestions
        }
        
        // Always toggle expanded state (keeps existing collapse/rotate behavior)
        withAnimation(.spring(duration: 0.5)) {
            isExpanded.toggle()
            if !isExpanded {
                lastVisibleButtonIndex = -1
                isLastButtonVisible = false
            }
        }
    }
    
    private func toggleExpanded() {
        triggerHaptic()
        
        withAnimation(.spring(duration: 0.5)) {
            isExpanded.toggle()
            if !isExpanded {
                lastVisibleButtonIndex = -1
                isLastButtonVisible = false
            }
        }
    }
    
    private func triggerHaptic() {
        HapticHelper.triggerHaptic(style: .light)
    }
    
    private func triggerScrollHaptic() {
        HapticHelper.triggerScrollHaptic()
    }

    private var suggestionLimit: Int {
        max(toolbarButtons.count + 1, maxSuggestionsCount)
    }

    private var chipTextColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.15)
    }

    private var chipBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.15)
    }
    
    // State management functions
    func setActiveButton(_ buttonType: ToolbarButtonType) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            activeButton = buttonType
        }
    }
    
    func clearActiveButton() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            activeButton = nil
        }
    }
    
    func isButtonActive(_ buttonType: ToolbarButtonType) -> Bool {
        return activeButton == buttonType
    }
}

// Preference key for tracking button visibility
struct ButtonVisibilityData: Equatable {
    let index: Int
    let frame: CGRect
}

struct ButtonVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [ButtonVisibilityData] = []
    
    static func reduce(value: inout [ButtonVisibilityData], nextValue: () -> [ButtonVisibilityData]) {
        value.append(contentsOf: nextValue())
    }
}

// Helper view for toolbar buttons
struct ToolbarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    private let buttonHeight: CGFloat = 40
    private let minButtonWidth: CGFloat = 88
    private let iconOnlyWidth: CGFloat = 48
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: label.isEmpty ? 16 : 13, weight: .semibold))
                if label.isEmpty {
                    EmptyView()
                } else if label == "Save to Clipboard" {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Save to")
                        Text("Clipboard")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                    .multilineTextAlignment(.leading)
                    .layoutPriority(1)
                } else if label == "Upload Context" {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Upload")
                        Text("Context")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                    .multilineTextAlignment(.leading)
                    .layoutPriority(1)
                } else {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, (label == "Save to Clipboard" || label == "Upload Context") ? 6 : 8)
            .frame(minWidth: label.isEmpty ? iconOnlyWidth : minButtonWidth, minHeight: buttonHeight)
            .background(
                isActive
                    ? Color(hex: "8B5CF6").opacity(0.2)
                    : buttonBackgroundColor
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isActive ? Color(hex: "8B5CF6") : Color.clear,
                        lineWidth: 2
                    )
            )
            .cornerRadius(8)
            .scaleEffect(isPressed ? 0.95 : (isActive ? 1.05 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isActive)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Adaptive colors for light/dark mode
    private var textColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.15)
    }
    
    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.15)
    }
}
