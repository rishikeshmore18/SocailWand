//
//  TestYourSocialSkillsView.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TestYourSocialSkillsView: View {
    private enum FunnelRoute: String, Hashable, Codable {
        case improvements
        case traits
        case keyboard
        case complete  // Screen 6 placeholder
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var stage: TestStage = .input
    @State private var userReply: String = ""
    @State private var ratingResponse: SocialRatingResponse?
    @State private var showContent = false
    @State private var showAlternatives = false
    @State private var arrowOffset: CGFloat = 0
    @State private var shakeToken: Int = 0
    @SceneStorage("funnelCurrentRoute") private var storedRoute: String?
    @State private var navigationPath = NavigationPath()
    @State private var selectedImprovements: [ImprovementOption] = []
    @State private var selectedTraits: [TraitOption] = []
    @FocusState private var isReplyFocused: Bool
    @State private var showPhotoUpload = false
    @State private var photoUploadSourceApp = "instagram"
    @State private var hasCheckedPhotoUpload = false  // Prevent multiple checks
    
    private let rater = SocialRater()
    private let incomingMessage = "I'm not mad at you, I just don't like how our convos have been lately"
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationDestination(for: FunnelRoute.self) { destination in
                    switch destination {
                    case .improvements:
                    ImprovementSelectionView { selected in
                            guard !selected.isEmpty else { return }
                            selectedImprovements = selected
                            go(to: .traits)
                        }
                        .navigationBarBackButtonHidden(true)

                    case .traits:
                        TraitsSelectionView { traits in
                            selectedTraits = traits
                            // Save selected trait titles for the keyboard via app group
                            if let defaults = UserDefaults(suiteName: "group.rishi-more.social-wand") {
                                let traitTitles = traits.map { $0.title }
                                defaults.set(traitTitles, forKey: "SelectedTraitTitles")
                                print("💾 Saved traits: \(traitTitles)")
                            }
                            go(to: .keyboard)
                    }
                    .navigationBarBackButtonHidden(true)

                    case .keyboard:
                        KeyboardSetupView {
                            go(to: .complete)
                        }
                        .navigationBarBackButtonHidden(true)
                    
                    case .complete:
                        OnboardingCompleteView()
                            .navigationBarBackButtonHidden(true)
                    }
                }
                .task {
                    // Restore route when NavigationStack first appears
                    restoreRouteIfNeeded()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Refresh permission status when app becomes active, if we're on keyboard screen
                    if oldPhase != .active && newPhase == .active {
                        if storedRoute == FunnelRoute.keyboard.rawValue {
                            KeyboardPermissionChecker.refreshStatus()
                        }
                    }
                }
                .onAppear {
                    // Only check once per view lifecycle to prevent race conditions
                    if !hasCheckedPhotoUpload {
                        hasCheckedPhotoUpload = true
                        checkPendingPhotoUpload()
                    }
                }
                .fullScreenCover(isPresented: $showPhotoUpload) {
                    PhotoUploadView(sourceApp: photoUploadSourceApp)
                }
        }
    }
    
    private var mainContent: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets
            let safeHeight = max(geo.size.height - safeInsets.top - safeInsets.bottom, 1)
            let isVeryCompact = safeHeight < 500
            let isCompactHeight = safeHeight < 760
            let horizontalPadding = max(CGFloat(16), geo.size.width * CGFloat(0.05))
            
            ZStack {
                ScrollView {
                    VStack(spacing: isVeryCompact ? 16 : 24) {
                        // Logo
                    logoView(isVeryCompact: isVeryCompact, isCompactHeight: isCompactHeight)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    
                        // Title
                        Text("Test Your Social Skills...")
                        .font(.system(size: isVeryCompact ? 24 : (isCompactHeight ? 28 : 32), weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    
                        // Scenario bubble
                        ScenarioBubble(text: incomingMessage)
                        .padding(.horizontal, horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    
                        // User reply field
                    if stage == .input || stage == .evaluating {
                        UserReplyField(
                            text: $userReply,
                                placeholder: "Type your reply here",
                            focus: $isReplyFocused,
                            shakeToken: shakeToken
                        )
                        .padding(.horizontal, horizontalPadding)
                            .id("replyField")
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    }
                    
                        // Helper text with arrow
                    if stage == .input || stage == .evaluating {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color.white)
                                .offset(y: arrowOffset)
                            
                                Text("How would you reply to this?")
                                .font(.system(size: isVeryCompact ? 16 : 18, weight: .semibold))
                                    .foregroundStyle(Color.white)
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    }
                    
                        // Evaluating spinner
                    if stage == .evaluating {
                        ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: 0x8B5CF6)))
                            .scaleEffect(1.2)
                            .padding(.vertical, 20)
                    }
                    
                        // Alternatives section
                    if stage == .showAlternatives, let response = ratingResponse {
                        WandReplySection(alternatives: response.alternatives)
                            .padding(.horizontal, horizontalPadding)
                            .opacity(showAlternatives ? 1 : 0)
                            .offset(y: showAlternatives ? 0 : 10)
                    }
                    
                        Spacer(minLength: 80)
                }
                .padding(.top, safeInsets.top + (isVeryCompact ? 8 : 16))
                }
                
                // Bottom CTA
                VStack {
                    Spacer()
                    
                    Button(action: handleCTAAction) {
                        Text(ctaButtonTitle)
                            .font(.system(size: isVeryCompact ? 17 : 19, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: isVeryCompact ? 52 : 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: 0x8B5CF6), Color(hex: 0x7C3AED)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: Color(hex: 0x8B5CF6).opacity(0.3), radius: 20, y: 8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, safeInsets.bottom + (isVeryCompact ? 12 : 16))
                    .opacity(showContent ? 1 : 0)
                }
                
                // Score modal overlay
                if stage == .showScore, let response = ratingResponse {
                    ScoreResultCard(
                        headlineOverride: response.headlineOverride,
                        displayScoreText: response.displayScoreText,
                        subline: response.subline,
                        primaryButtonTitle: "Help me out 😉",
                        onDismiss: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                stage = .showAlternatives
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    showAlternatives = true
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                showContent = true
            }
            startArrowAnimation()
        }
    }
    
    private func checkPendingPhotoUpload() {
        // Wait 1 second to ensure view is in window hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performPhotoUploadCheck()
        }
    }
    
    private func performPhotoUploadCheck() {
        print("🔍 Checking for pending photo upload...")
        
        guard let defaults = UserDefaults(suiteName: "group.rishi-more.social-wand"),
              defaults.bool(forKey: "PendingPhotoUpload") else {
            print("❌ No pending photo upload")
            return
        }
        
        print("✅ Found pending photo upload!")
        
        // Check if request is recent (within last 5 minutes)
        if let requestTime = defaults.object(forKey: "PhotoUploadRequestTime") as? Date,
           Date().timeIntervalSince(requestTime) < 300 {
            
            // Get source app (DON'T clear flag yet)
            photoUploadSourceApp = defaults.string(forKey: "PhotoUploadSourceApp") ?? "instagram"
            
            print("✅ Showing photo upload view for source: \(photoUploadSourceApp)")
            
            // Show modal
            showPhotoUpload = true
            
            // Clear flag AFTER modal is shown (wait 1 second)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                defaults.set(false, forKey: "PendingPhotoUpload")
                defaults.removeObject(forKey: "PhotoUploadRequestTime")
                print("✅ Flag cleared after modal presented")
            }
        } else {
            print("⚠️ Photo upload request too old, clearing...")
            defaults.set(false, forKey: "PendingPhotoUpload")
            defaults.removeObject(forKey: "PhotoUploadRequestTime")
        }
    }
    
    private func logoView(isVeryCompact: Bool, isCompactHeight: Bool) -> some View {
        let logoSize: CGFloat = isVeryCompact ? 80 : (isCompactHeight ? 100 : 120)
        
        return Image("SocialWandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: logoSize, height: logoSize)
            .shadow(color: Color.white.opacity(0.08), radius: 12, y: 6)
    }
    
    private var ctaButtonTitle: String {
        switch stage {
        case .input, .evaluating:
            return "Rate my reply"
        case .showAlternatives:
            return "Improve my social skills ;)"
        case .showScore:
            return ""
        }
    }
    
    private func handleCTAAction() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        
        switch stage {
        case .input:
            guard !userReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if let replyField = findReplyField() {
                    replyField.triggerShake()
                }
                return
            }
            
            stage = .evaluating
            
            Task {
                do {
                    try await Task.sleep(nanoseconds: 600_000_000)
                    let traitNames = selectedTraits.map { $0.title }
                    let response = try await rater.rate(
                        incoming: incomingMessage,
                        reply: userReply,
                        traits: traitNames
                    )
                    await MainActor.run {
                        ratingResponse = response
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            stage = .showScore
                        }
                    }
                } catch {
                    await MainActor.run {
                        stage = .input
                    }
                }
            }
            
        case .showAlternatives:
            // Navigate to Screen 3 (Improvement Selection)
            go(to: .improvements)
            
        default:
            break
        }
    }
    
    private func findReplyField() -> UserReplyField? {
        // Helper to access reply field for shake animation
        // SwiftUI doesn't provide direct access, so we use a workaround
        return nil // Simplified for now
    }
    
    private func startArrowAnimation() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            arrowOffset = -8
        }
    }
}

// MARK: - Navigation Helpers

private extension TestYourSocialSkillsView {
    /// Navigate to a route and store it for restoration
    private func go(to route: FunnelRoute) {
        navigationPath.append(route)
        storedRoute = route.rawValue
    }
    
    /// Restore the navigation route when the view appears
    private func restoreRouteIfNeeded() {
        guard navigationPath.isEmpty,
              let raw = storedRoute,
              let route = FunnelRoute(rawValue: raw) else { return }
        
        navigationPath.append(route)
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

