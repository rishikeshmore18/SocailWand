//
//  SettingsView.swift
//  social wand
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    
    // State for sound feedback toggle
    @AppStorage("SoundFeedbackEnabled", store: UserDefaults(suiteName: "group.rishi-more.social-wand"))
    private var soundFeedbackEnabled: Bool = false
    
    // State for haptic feedback
    @AppStorage("HapticFeedbackLevel", store: UserDefaults(suiteName: "group.rishi-more.social-wand"))
    private var hapticFeedbackLevel: String = "soft"  // "soft", "strong", "off"
    
    private var hapticDisplayText: String {
        switch hapticFeedbackLevel {
        case "soft": return "Soft"
        case "strong": return "Strong"
        case "off": return "Off"
        default: return "Soft"
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let safeHeight = max(geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom, 1)
            let breakpoint = LayoutBreakpoint.forHeight(safeHeight)
            
            // Dynamic sizing
            let horizontalPadding = max(CGFloat(20), geo.size.width * 0.05)
            
            VStack(spacing: 0) {
                // Title at the top
                Text("Settings")
                    .font(.system(size: breakpoint == .veryCompact ? 28 : (breakpoint == .compact ? 32 : 36), weight: .bold, design: .rounded))
                    .foregroundStyle(AppBrand.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                
                // Settings list
                ScrollView {
                    VStack(spacing: 0) {
                        // Button Order row
                        NavigationLink(destination: ButtonOrderView()) {
                            settingRow(
                                icon: "arrow.up.arrow.down",
                                title: "Button Order",
                                showChevron: true
                            )
                        }
                        
                        Divider()
                            .padding(.leading, horizontalPadding + 44)
                        
                        // Sound Feedback row
                        settingRow(
                            icon: "speaker.wave.2",
                            title: "Sound Feedback",
                            trailing: {
                                Toggle("", isOn: $soundFeedbackEnabled)
                                    .labelsHidden()
                                    .tint(Color(hex: "8B5CF6"))
                            }
                        )
                        
                        Divider()
                            .padding(.leading, horizontalPadding + 44)
                        
                        // Haptic Feedback row
                        NavigationLink(destination: HapticFeedbackPickerView(selectedLevel: $hapticFeedbackLevel)) {
                            settingRow(
                                icon: "hand.tap",
                                title: "Haptic Feedback",
                                subtitle: hapticDisplayText,
                                showChevron: true
                            )
                        }
                    }
                    .padding(.top, 24)
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
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(AppBrand.purple)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                showContent = true
            }
        }
    }
    
    // Setting row component
    @ViewBuilder
    private func settingRow<T: View>(
        icon: String,
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = false,
        @ViewBuilder trailing: () -> T = { EmptyView() }
    ) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: "8B5CF6"))
                .frame(width: 28, height: 28)
            
            // Title + Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Trailing content
            trailing()
            
            // Chevron
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
