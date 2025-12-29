//
//  OnboardingCompleteView.swift
//  social wand
//
//  Created by Cursor on 11/14/25.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @AppStorage("hasStartedOnboarding") private var hasStartedOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    
    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets
            let safeHeight = max(geo.size.height - safeInsets.top - safeInsets.bottom, 1)
            let isVeryCompact = safeHeight < 500
            let isCompactHeight = safeHeight < 760
            let horizontalPadding = max(CGFloat(16), geo.size.width * CGFloat(0.05))
            let ctaHeight: CGFloat = isCompactHeight ? 52 : 56
            let bottomPadding = max(CGFloat(32), safeInsets.bottom + 12)
            
            VStack(spacing: isVeryCompact ? 20 : 32) {
                Spacer()
                
                Image("SocialWandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isVeryCompact ? 100 : 120, height: isVeryCompact ? 100 : 120)
                    .shadow(color: Color.white.opacity(0.08), radius: 12, y: 6)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.9)
                
                VStack(spacing: 12) {
                    Text("You're All Set! 🎉")
                        .font(.system(size: isVeryCompact ? 26 : (isCompactHeight ? 30 : 34), weight: .bold, design: .rounded))
                        .foregroundStyle(AppBrand.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Social Wand is ready to help you communicate like a pro")
                        .font(.system(size: isVeryCompact ? 15 : 17))
                        .foregroundStyle(AppBrand.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            CTASection()
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    @ViewBuilder
    private func CTASection() -> some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets
            let safeHeight = max(geo.size.height - safeInsets.top - safeInsets.bottom, 1)
            let isCompactHeight = safeHeight < 760
            let horizontalPadding = max(CGFloat(16), geo.size.width * CGFloat(0.05))
            let ctaHeight: CGFloat = isCompactHeight ? 52 : 56
            let bottomPadding = max(CGFloat(32), safeInsets.bottom + 12)
            
            Button {
                hasCompletedOnboarding = true  // Mark onboarding as complete
                hasStartedOnboarding = false   // Reset onboarding flag
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.system(size: isCompactHeight ? 17 : 19, weight: .bold))
                    .foregroundStyle(AppBrand.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ctaHeight)
                    .background(
                        LinearGradient(
                            colors: [AppBrand.purple, AppBrand.purpleDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: AppBrand.purple.opacity(0.3), radius: 20, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, bottomPadding)
            .background(
                Color.black
                    .opacity(0.92)
                    .blur(radius: 20)
                    .ignoresSafeArea()
            )
            .opacity(showContent ? 1 : 0)
        }
        .frame(height: 120)
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingCompleteView()
}

