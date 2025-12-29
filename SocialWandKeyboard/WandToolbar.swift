import SwiftUI

struct WandToolbar: View {
    let onWandTap: () -> Void
    let onToneButtonTap: () -> Void
    let onLengthButtonTap: () -> Void  // ✅ NEW
    let onUploadButtonTap: () -> Void  // ✅ NEW
    let onMenuButtonTap: () -> Void  // ✅ NEW
    let isSuggestionsVisible: () -> Bool
    let onCloseSuggestions: (() -> Void)?
    @State private var isExpanded = false
    @State private var isLastButtonVisible = false
    @State private var lastVisibleButtonIndex: Int = -1
    
    init(onWandTap: @escaping () -> Void, onToneButtonTap: @escaping () -> Void, onLengthButtonTap: @escaping () -> Void, onUploadButtonTap: @escaping () -> Void, onMenuButtonTap: @escaping () -> Void, isSuggestionsVisible: @escaping () -> Bool, onCloseSuggestions: (() -> Void)?) {
        self.onWandTap = onWandTap
        self.onToneButtonTap = onToneButtonTap
        self.onLengthButtonTap = onLengthButtonTap
        self.onUploadButtonTap = onUploadButtonTap
        self.onMenuButtonTap = onMenuButtonTap
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
    }
    
    // Toolbar button definitions
    private var toolbarButtons: [(icon: String, label: String, action: () -> Void)] {
        return [
            ("photo.on.rectangle", "Upload", onUploadButtonTap),  // ✅ WIRED UP
            ("waveform", "Tone", onToneButtonTap),
            ("text.alignleft", "Length", onLengthButtonTap),  // ✅ WIRED UP
            ("arrow.clockwise", "Gen", onWandTap),
            ("chevron.down", "Menu", onMenuButtonTap)  // ✅ NEW: 5th button
        ]
    }
    
    // Handle button visibility
    private func handleButtonVisibility(_ values: [ButtonVisibilityData]) {
        // Check if last button (Menu - index 4) is visible
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
    
    // Regular haptic feedback
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Scroll haptic feedback (rigid for detent feel)
    private func triggerScrollHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
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
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(buttonBackgroundColor)
            .cornerRadius(8)
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
