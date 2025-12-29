//
//  ContentView.swift
//  social wand
//
//  Created by Trishali Rao on 11/6/25.
//

import SwiftUI

private enum HapticFeedbackStyle {
    case light
    case medium
    case soft
}

#if canImport(UIKit)
import UIKit

private enum HapticEngine {
    static func impact(_ style: HapticFeedbackStyle) {
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .soft:
            if #available(iOS 17.0, *) {
                generator = UIImpactFeedbackGenerator(style: .soft)
            } else {
                generator = UIImpactFeedbackGenerator(style: .light)
            }
        }
        generator.prepare()
        generator.impactOccurred()
    }
}
#else
private enum HapticEngine {
    static func impact(_ style: HapticFeedbackStyle) {}
}
#endif

struct ContentView: View {
    var body: some View {
        OnboardingHeroView()
    }
}

struct OnboardingHeroView: View {
    @Namespace private var logoNamespace
    @State private var didAnimate = false
    @State private var showHero = false
    @State private var showContent = false
    @State private var buttonPop = false
    @State private var flowStarted = false
    @State private var languageSheetPresented = false
    @State private var selectedLanguage: Language = .english
    @AppStorage("hasStartedOnboarding") private var showTestScreen = false
    @State private var pendingDeepLink = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let safeInsets = geo.safeAreaInsets
                let safeHeight = max(height - safeInsets.top - safeInsets.bottom, 1)
                let shortestSide = min(width, height)
                
                let isVeryCompact = safeHeight < 500
                let logoScaleFactor = isVeryCompact ? 0.35 : (safeHeight < 700 ? 0.45 : (height < 800 ? 0.60 : 0.70))
                let heroLogoSide = (shortestSide * logoScaleFactor).clamped(to: 140...320)
                let splashLogoSide = (shortestSide * 0.82).clamped(to: 190...320)

                ZStack {
                    if showHero {
                        heroStack(
                            geo: geo,
                            logoSide: heroLogoSide
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    } else {
                        splashLogo(size: splashLogoSide)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $languageSheetPresented) {
            LanguageSheet(selectedLanguage: $selectedLanguage)
        }
#if os(iOS)
        .fullScreenCover(isPresented: $showTestScreen) {
            TestYourSocialSkillsView()
        }
#else
        .sheet(isPresented: $showTestScreen) {
            TestYourSocialSkillsView()
        }
#endif
        .onAppear {
            checkForDeepLink()
        }
        .task { await startFlow() }
        .preferredColorScheme(.dark)
    }
}

private extension OnboardingHeroView {
    func heroStack(geo: GeometryProxy, logoSide: CGFloat) -> some View {
        let safeInsets = geo.safeAreaInsets
        let safeHeight = max(geo.size.height - safeInsets.top - safeInsets.bottom, 1)
        let isVeryCompact = safeHeight < 500
        let isCompactHeight = safeHeight < 760
        let horizontalPadding = max(CGFloat(16), geo.size.width * CGFloat(0.05))
        let heroSpacing = isVeryCompact ? CGFloat(6) : (isCompactHeight ? CGFloat(10) : CGFloat(16))
        let bottomSpacer = max(CGFloat(isVeryCompact ? 16 : 28), safeInsets.bottom * 0.4)
        let ctaHeight: CGFloat = isCompactHeight ? 52 : 56
        let ctaSpacing: CGFloat = 16 + CGFloat(isCompactHeight ? 11 : 12)
        let bottomPadding = max(CGFloat(32), safeInsets.bottom + 12)
        let reservedForCTA = ctaHeight + ctaSpacing + bottomPadding
        let heroViewport = max(
            safeHeight - reservedForCTA - bottomSpacer,
            isVeryCompact ? 280 : (isCompactHeight ? 320 : 360)
        )
        
        let heroContent = VStack(spacing: heroSpacing) {
                logoImage
                    .frame(width: logoSide, height: logoSide)
                    .scaleEffect(showHero ? 1.0 : 0.9)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showHero)
                    .accessibilityHidden(true)

                        Text("Type Anywhere Like a Pro 😎")
                    .font(.system(size: isVeryCompact ? CGFloat(22) : (isCompactHeight ? CGFloat(28) : CGFloat(32)), weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35), value: showContent)

                FlippableFeaturePanel(
                    frontItems: [
                        FeatureItem(iconAsset: "ic_phone_camera", fallbackSF: "camera.viewfinder", title: "Upload any chat or screenshot"),
                        FeatureItem(iconAsset: "ic_keyboard_check", fallbackSF: "keyboard", title: "Social Wand reads the tone and context", iconScale: 1.25),
                        FeatureItem(iconAsset: "ic_bubbles_apply", fallbackSF: "ellipsis.bubble", title: "Choose your tone and send instantly", iconScale: 1.15)
                    ],
                    backItems: [
                        FeatureItem(iconAsset: "ic_chat_outline", fallbackSF: "bubble.left.and.bubble.right", title: "Start conversations easily"),
                        FeatureItem(iconAsset: "ic_thumb_up", fallbackSF: "hand.thumbsup", title: "Improve your reply game"),
                        FeatureItem(iconAsset: "ic_smiley", fallbackSF: "face.smiling", title: "Read people's emotions")
                    ],
            viewportHeight: heroViewport
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.35), value: showContent)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
        .frame(maxHeight: heroViewport, alignment: .center)

        return VStack(spacing: 0) {
            HStack {
                Spacer()
                LanguagePill(language: selectedLanguage) {
                    languageSheetPresented = true
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, safeInsets.top + (isVeryCompact ? 6 : 12))
            .opacity(showHero ? 1 : 0)
            .animation(.easeOut(duration: 0.35), value: showHero)

            Spacer(minLength: 0)

            heroContent
                .layoutPriority(1)

            Spacer(minLength: bottomSpacer)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 16) {
                Button {
                    // TODO: remove after QA
                    showTestScreen = true
                } label: {
                    Text("Get Started for Free")
                        .font(.system(size: CGFloat(ctaHeight == 52 ? 17 : 19), weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: ctaHeight)
                }
                .buttonStyle(PrimaryButtonStyle())
                .scaleEffect(buttonPop ? 1 : 0.9)
                .opacity(buttonPop ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: buttonPop)

                Text(legalAttributedText)
                    .font(.system(size: CGFloat(isCompactHeight ? 11 : 12)))
                    .fontWeight(.regular)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.9)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35), value: showContent)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, bottomPadding)
            .background(
                Color.black
                    .opacity(0.92)
                    .blur(radius: 20)
                    .ignoresSafeArea()
            )
        }
    }

    func splashLogo(size: CGFloat) -> some View {
        ZStack {
            Color.black
            logoImage
                .frame(width: size, height: size)
                .scaleEffect(didAnimate ? 1.0 : 0.82)
                .animation(.spring(response: 0.42, dampingFraction: 0.8), value: didAnimate)
        }
    }

    var logoImage: some View {
        Image("SocialWandLogo")
            .resizable()
            .scaledToFit()
            .shadow(color: Color.white.opacity(0.08), radius: 12, y: 6)
            .matchedGeometryEffect(id: "heroLogo", in: logoNamespace)
    }

    func startFlow() async {
        guard !flowStarted else { return }
        flowStarted = true

        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            didAnimate = true
        }

        try? await Task.sleep(nanoseconds: 450_000_000)
        withAnimation(.easeInOut(duration: 0.48)) {
            showHero = true
        }

        try? await Task.sleep(nanoseconds: 160_000_000)
        withAnimation(.easeOut(duration: 0.35)) {
            showContent = true
        }

        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.spring(response: 0.44, dampingFraction: 0.68)) {
            buttonPop = true
        }
    }

    var legalAttributedText: AttributedString {
        var prefix = AttributedString("By continuing you agree to our ")
        prefix.foregroundColor = Color.secondary

        var terms = AttributedString("Terms of Service")
        terms.underlineStyle = .single

        var conjunction = AttributedString(" and ")
        conjunction.foregroundColor = Color.secondary

        var privacy = AttributedString("Privacy Policy")
        privacy.underlineStyle = .single

        var combined = prefix
        combined.append(terms)
        combined.append(conjunction)
        combined.append(privacy)
        return combined
    }
    
    private func checkForDeepLink() {
        // Check if app was opened via deep link for photo upload
        guard let defaults = UserDefaults(suiteName: "group.rishi-more.social-wand"),
              defaults.bool(forKey: "PendingPhotoUpload") else {
            return
        }
        
        // Check if request is recent (within last 5 minutes)
        if let requestTime = defaults.object(forKey: "PhotoUploadRequestTime") as? Date,
           Date().timeIntervalSince(requestTime) < 300 {
            
            print("🔗 Deep link detected - bypassing onboarding to show photo upload")
            
            // Skip onboarding and go straight to main screen
            showTestScreen = true
            pendingDeepLink = true
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x8B5CF6), Color(hex: 0x7C3AED)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: .white.opacity(0.08), radius: 14, y: 6)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

private struct LanguagePill: View {
    let language: Language
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
            Image(systemName: "globe")
                Text(language.displayName)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change language")
    }
}

private struct LanguageSheet: View {
    @Binding var selectedLanguage: Language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Language.allCases, id: \.self) { language in
                    Button {
                        selectedLanguage = language
                    } label: {
                        HStack {
                            Text(language.fullName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if language == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Language")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AppLogosBackdrop: View {
    private let icons = [
        "heart.fill", "message.fill", "camera.fill",
        "bolt.fill", "face.smiling", "bubble.left.and.bubble.right.fill"
    ]

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let columns = max(Int(geo.size.width / 64), 1)
                let rows = max(Int(geo.size.height / 64), 1)

                Canvas { context, _ in
                    for row in 0..<rows {
                        for column in 0..<columns {
                            let x = CGFloat(column) * 64 + 32
                            let y = CGFloat(row) * 64 + 32
                            let symbol = icons[(row + column) % icons.count]
                            var resolved = context.resolve(Image(systemName: symbol))
                            resolved.shading = .color(.white.opacity(0.06))
                            context.draw(resolved, at: CGPoint(x: x, y: y))
                        }
                    }
                }
            }
        }
        .blendMode(.plusLighter)
        .background(Color.black)
    }
}

// MARK: - Brand Colors

private enum Brand {
    static let purple = Color(hex: 0x8B5CF6)
    static let amber = Color(hex: 0xF59E0B)
    static let cardBackground = Color.black.opacity(0.86)
    static let cardBorder = Color.white.opacity(0.06)
    static let iconBackground = Color.white.opacity(0.04)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textHint = Color.white.opacity(0.5)
}

// MARK: - Feature Data Model

private struct FeatureItem: Identifiable {
    let id = UUID()
    let iconAsset: String
    let fallbackSF: String
    let title: String
    let iconScale: CGFloat

    init(iconAsset: String, fallbackSF: String, title: String, iconScale: CGFloat = 1.0) {
        self.iconAsset = iconAsset
        self.fallbackSF = fallbackSF
        self.title = title
        self.iconScale = iconScale
    }
}

// MARK: - Feature Row Component

private struct FeatureRow: View {
    let item: FeatureItem
    let iconDiameter: CGFloat
    let iconSize: CGFloat
    let fontSize: CGFloat
    let verticalPadding: CGFloat
    
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            iconGraphic
                .scaledToFit()
                .frame(
                    width: iconSize * item.iconScale,
                    height: iconSize * item.iconScale
                )
                .shadow(color: Brand.purple.opacity(0.4), radius: 12, x: 0, y: 4)
                .shadow(color: Color.white.opacity(0.15), radius: 2, x: 0, y: -1)

            Text(item.title)
                .foregroundStyle(Brand.textPrimary)
                .font(.system(size: fontSize, weight: .bold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, verticalPadding)
        .frame(minHeight: max(iconSize * item.iconScale, fontSize * 2.1), alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var iconGraphic: some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(named: item.iconAsset) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackIcon
        }
        #else
        fallbackIcon
        #endif
    }

    private var fallbackIcon: some View {
        Image(systemName: item.fallbackSF)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(Brand.purple)
    }
}

// MARK: - Flippable Feature Panel

private struct FlippableFeaturePanel: View {
    let frontItems: [FeatureItem]
    let backItems: [FeatureItem]
    let viewportHeight: CGFloat
    
    @State private var rotation: Double = 0
    @State private var hasAutoFlipped = false
    @State private var isDragging = false
    @State private var dragStart: CGFloat = 0
    @State private var floatOffset: CGFloat = 0
    
    private var isShowingBack: Bool {
        rotation >= 90
    }
    
    private var isCompactViewport: Bool {
        viewportHeight < 760
    }
    
    var body: some View {
        let cardHeight = FlippableFeaturePanel.preferredHeight(for: viewportHeight)
        let isVeryCompact = viewportHeight < 500
        return GeometryReader { geometry in
            let iconDiameter = isVeryCompact ? CGFloat(70) : (isCompactViewport ? CGFloat(100) : CGFloat(120))
            let iconSize = isVeryCompact ? CGFloat(60) : (isCompactViewport ? CGFloat(80) : CGFloat(100))
            let rowFontSize = isVeryCompact ? CGFloat(15) : (isCompactViewport ? CGFloat(17) : CGFloat(19))
            let maxCardWidth = isVeryCompact ? CGFloat(340) : (isCompactViewport ? CGFloat(380) : CGFloat(460))
            let cardWidth = min(geometry.size.width, maxCardWidth)
            let rowPadding = isVeryCompact ? CGFloat(8) : (isCompactViewport ? CGFloat(12) : CGFloat(16))
            let rowSpacing = isVeryCompact ? CGFloat(14) : (isCompactViewport ? CGFloat(20) : CGFloat(26))
            
            return ZStack {
                CardSurface(width: cardWidth, height: cardHeight, footerText: "Tap to flip") {
                    VStack(alignment: .center, spacing: rowSpacing) {
                        ForEach(frontItems) { item in
                            FeatureRow(
                                item: item,
                                iconDiameter: iconDiameter,
                                iconSize: iconSize,
                                fontSize: rowFontSize,
                                verticalPadding: rowPadding
                            )
                        }
                    }
                }
                .opacity(isShowingBack ? 0 : 1)
                .accessibilityHidden(isShowingBack)
                
                CardSurface(width: cardWidth, height: cardHeight, footerText: "Tap to flip") {
                    VStack(alignment: .center, spacing: rowSpacing) {
                        ForEach(backItems) { item in
                            FeatureRow(
                                item: item,
                                iconDiameter: iconDiameter,
                                iconSize: iconSize,
                                fontSize: rowFontSize,
                                verticalPadding: rowPadding
                            )
                        }
                    }
                }
                .opacity(isShowingBack ? 1 : 0)
                .accessibilityHidden(!isShowingBack)
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .offset(y: floatOffset)
            .contentShape(Rectangle())
            .simultaneousGesture(tapGesture)
            .simultaneousGesture(dragGesture(cardWidth: cardWidth))
            .onAppear {
                performAutoFlip()
                startFloatingAnimation()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: cardHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isShowingBack ? "Benefits panel" : "How it works panel")
        .accessibilityHint("Double tap or swipe to flip")
    }
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                guard !isDragging else { return }
                performFlip(animated: true, withHaptic: true)
            }
    }
    
    private func dragGesture(cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStart = value.startLocation.x
                }
                
                let delta = value.translation.width
                let rotationDelta = (delta / cardWidth) * 180
                let proposed = rotation - rotationDelta
                
                rotation = proposed.clamped(to: 0...180)
            }
            .onEnded { value in
                isDragging = false
                dragStart = 0
                
                let velocity = value.predictedEndTranslation.width - value.translation.width
                settleWithVelocity(velocity)
            }
    }
    
    private func performAutoFlip() {
        guard !hasAutoFlipped else { return }
        hasAutoFlipped = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                rotation = 180
            }
            HapticEngine.impact(.light)
        }
    }
    
    private func performFlip(animated: Bool, withHaptic: Bool) {
        let targetRotation: Double = rotation < 90 ? 180 : 0
        
        if animated {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                rotation = targetRotation
            }
        } else {
            rotation = targetRotation
        }
        
        if withHaptic {
            HapticEngine.impact(.medium)
        }
    }
    
    private func settleWithVelocity(_ velocity: CGFloat) {
        let threshold: CGFloat = 100
        let targetRotation: Double
        
        if abs(velocity) > threshold {
            targetRotation = velocity < 0 ? 180 : 0
        } else {
            targetRotation = rotation >= 90 ? 180 : 0
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            rotation = targetRotation
        }
        
        HapticEngine.impact(.soft)
    }
    
    private func startFloatingAnimation() {
        let amplitude: CGFloat = CGFloat(isCompactViewport ? 6 : 10)
        withAnimation(
            .easeInOut(duration: 2.8)
            .repeatForever(autoreverses: true)
        ) {
            floatOffset = -amplitude
        }
    }
}

private extension FlippableFeaturePanel {
    static func preferredHeight(for viewportHeight: CGFloat) -> CGFloat {
        let isVeryCompact = viewportHeight < 500
        let compact = viewportHeight < 760
        
        if isVeryCompact {
            let minHeight: CGFloat = 200
            let maxHeight: CGFloat = 280
            let calculated = viewportHeight * 0.52
            return min(max(calculated, minHeight), maxHeight)
        } else if compact {
            let minHeight: CGFloat = 280
            let maxHeight: CGFloat = 360
            let calculated = viewportHeight * 0.65
            return min(max(calculated, minHeight), maxHeight)
        } else {
            // Allow smaller minimum (300 instead of 360) when viewport is tight
            let minHeight: CGFloat = 300
            let maxHeight: CGFloat = 430
            let calculated = viewportHeight * 0.70
            return min(max(calculated, minHeight), maxHeight)
        }
    }
}

// MARK: - Card Surface

private struct CardSurface<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let footerText: String
    @ViewBuilder let content: Content
    
    var body: some View {
        let cornerRadius: CGFloat = 36
        let isVeryCompact = height < 250
        let horizontalPadding: CGFloat = isVeryCompact ? 16 : 24
        let verticalPadding: CGFloat = isVeryCompact ? 18 : 28
        
        return VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: isVeryCompact ? 8 : 14)

            Text(footerText)
                .font(.system(size: isVeryCompact ? 11 : 13, weight: .semibold))
                .foregroundStyle(Brand.textHint)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(width: width, height: height)
        .background(glassSurface(cornerRadius: cornerRadius))
        .overlay(glassEdge(cornerRadius: cornerRadius))
        .overlay(glassHighlight(cornerRadius: cornerRadius))
        .shadow(color: Brand.purple.opacity(0.22), radius: 36, x: 0, y: 22)
        .shadow(color: Color.black.opacity(0.60), radius: 54, x: 0, y: 36)
    }

    private func glassSurface(cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.50)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.black.opacity(0.70),
                            Color.black.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private func glassEdge(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3.2
            )
            .blendMode(.screen)
    }

    private func glassHighlight(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.9)
            .blur(radius: 0.8)
            .offset(x: -1.5, y: -1.5)
            .opacity(0.7)
    }
}

// MARK: - Utility Extensions

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private enum Language: String, CaseIterable {
    case english = "EN"
    case spanish = "ES"

    var displayName: String {
        rawValue
    }

    var fullName: String {
        switch self {
        case .english:
            "English"
        case .spanish:
            "Spanish"
        }
    }
}

// Color extension moved to Theme/UIStyles.swift

#Preview {
    ContentView()
}
