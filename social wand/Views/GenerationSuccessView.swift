//
//  GenerationSuccessView.swift
//  social wand
//

import SwiftUI

struct GenerationSuccessView: View {
    let allGenerations: [[String]]  // Array of generations, each containing [safe, bold]
    let sourceApp: String
    let onGenerateAnother: () -> Void
    let onGoBack: () -> Void
    let onGoHome: () -> Void
    
    @State private var selectedGenerationIndex: Int = 0  // Which generation (batch)
    @State private var selectedAlternativeIndex: Int = 0  // Which alternative (safe/bold)
    @State private var showCopied = false
    @State private var isReturning = false
    @Environment(\.dismiss) var dismiss
    
    // Computed property for flattened alternatives with metadata
    private var flattenedAlternatives: [(text: String, generationIndex: Int, alternativeIndex: Int, badge: String)] {
        allGenerations.enumerated().flatMap { genIndex, alternatives in
            alternatives.enumerated().map { altIndex, text in
                (
                    text: text,
                    generationIndex: genIndex,
                    alternativeIndex: altIndex,
                    badge: altIndex == 0 ? "Safe" : "Bold"
                )
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // FIXED TOP SECTION
            VStack(spacing: 24) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding(.top, 40)
                
                Text("Generated!")
                    .font(.system(size: 28, weight: .bold))
                
                // Label
                HStack {
                    Text("AI Generated:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            // SCROLLABLE MESSAGES SECTION
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(allGenerations.enumerated()), id: \.offset) { genIndex, alternatives in
                        // Batch separator (except before first generation)
                        if genIndex > 0 {
                            batchSeparator
                                .padding(.vertical, 12)
                        }
                        
                        // Generation cards (Safe + Bold)
                        ForEach(Array(alternatives.enumerated()), id: \.offset) { altIndex, text in
                            messageCard(
                                text: text,
                                generationIndex: genIndex,
                                alternativeIndex: altIndex,
                                badge: altIndex == 0 ? "Safe" : "Bold"
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)
            
            Spacer()
            
            // FIXED BOTTOM BUTTONS
            VStack(spacing: 12) {
                // Copy Selected Button
                Button(action: copyAndReturn) {
                    HStack(spacing: 12) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 18, weight: .semibold))
                        Text(showCopied ? "Copied!" : "Copy Selected")
                            .font(.system(size: 17, weight: .semibold))
                    }
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
                .disabled(isReturning)
                
                // Generate Another Button
                Button(action: {
                    onGenerateAnother()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Generate Another")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "8B5CF6"), lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden(true)  // ✅ Hide default back button since we have custom one
        .gesture(
            // ✅ NEW: Enable swipe-back gesture
            DragGesture()
                .onEnded { gesture in
                    // Detect swipe from left edge to right (>100 points horizontal movement)
                    if gesture.translation.width > 100 && gesture.translation.height < 50 && gesture.translation.height > -50 {
                        onGoBack()
                    }
                }
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    onGoBack()
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
            
            // Home button on right side
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    onGoHome()
                }) {
                    HStack(spacing: 6) {
                        Text("Home")
                            .font(.system(size: 17))
                        Image(systemName: "house.fill")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "8B5CF6"))
                }
            }
        }
    }
    
    @ViewBuilder
    private func messageCard(text: String, generationIndex: Int, alternativeIndex: Int, badge: String) -> some View {
        let isSelected = selectedGenerationIndex == generationIndex && selectedAlternativeIndex == alternativeIndex
        
        VStack(alignment: .leading, spacing: 12) {
            // Badge (Safe = green, Bold = purple)
            HStack {
                Text(badge)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badge == "Safe" ? Color.green : Color(hex: "8B5CF6"))
                    .cornerRadius(8)
                Spacer()
            }
            
            // Message text
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: "8B5CF6") : Color.clear, lineWidth: 3)
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                selectedGenerationIndex = generationIndex
                selectedAlternativeIndex = alternativeIndex
            }
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func copyAndReturn() {
        // Ensure selection is valid
        guard selectedGenerationIndex >= 0 && selectedGenerationIndex < allGenerations.count else {
            return
        }
        
        let generation = allGenerations[selectedGenerationIndex]
        
        guard selectedAlternativeIndex >= 0 && selectedAlternativeIndex < generation.count else {
            return
        }
        
        let selectedMessage = generation[selectedAlternativeIndex]
        
        // 1. Copy to clipboard
        UIPasteboard.general.string = selectedMessage
        
        // 2. Show "Copied!" feedback
        withAnimation(.spring(response: 0.3)) {
            showCopied = true
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // 3. Save to App Group (for banner in keyboard)
        SharedSuggestionData.save(
            suggestion: selectedMessage,
            sourceApp: sourceApp
        )
        
        // 4. Reset "Copied!" text after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.3)) {
                showCopied = false
            }
        }
    }
    
    private var batchSeparator: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 1)
            .overlay(
                Text("Previous")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
            )
    }
}
