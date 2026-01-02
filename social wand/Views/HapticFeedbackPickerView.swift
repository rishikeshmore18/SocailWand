//
//  HapticFeedbackPickerView.swift
//  social wand
//

import SwiftUI

struct HapticFeedbackPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLevel: String
    
    private let options: [(id: String, label: String, description: String)] = [
        ("soft", "Soft Haptic", "Light, subtle feedback"),
        ("strong", "Strong Haptic", "Firm, noticeable feedback"),
        ("off", "Haptic Off", "No haptic feedback")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Options list
            VStack(spacing: 0) {
                ForEach(options, id: \.id) { option in
                    Button(action: {
                        selectOption(option.id)
                    }) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.label)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text(option.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if selectedLevel == option.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "8B5CF6"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(selectedLevel == option.id ? Color(hex: "8B5CF6").opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if option.id != options.last?.id {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(.top, 24)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Haptic Feedback")
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
                    .foregroundStyle(Color(hex: "8B5CF6"))
                }
            }
        }
    }
    
    private func selectOption(_ level: String) {
        selectedLevel = level
        
        // Trigger haptic preview based on selection
        switch level {
        case "soft":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "strong":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "off":
            // No haptic
            break
        default:
            break
        }
        
        print("✅ Haptic level changed to: \(level)")
    }
}

#Preview {
    NavigationStack {
        HapticFeedbackPickerView(selectedLevel: .constant("soft"))
    }
}


