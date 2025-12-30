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
        HStack(spacing: 8) {
            Text("Suggestions")
                .font(.system(size: 18, weight: .bold))
            
            // Show "New" indicator only after Generate More (when > 2 suggestions)
            if viewModel.suggestions.count > 2 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8B5CF6"))
                    
                    Text("New")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "8B5CF6"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "8B5CF6").opacity(0.1))
                )
            }
            
            Spacer()
        }
    }
    
    private func suggestionCard(text: String, badge: String, badgeColor: Color, index: Int) -> some View {
        let isSelected = selectedSuggestionIndex == index
        
        return ZStack(alignment: .topTrailing) {
            // Main card content
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
            .padding(16)
            .background(cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "8B5CF6") : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture {
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
            }
            
            // Overlay Apply button (only shows when selected)
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
                .padding(.top, 16)
                .padding(.trailing, 16)
                .transition(.scale.combined(with: .opacity))
            }
        }
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

