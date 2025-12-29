//
//  HomeView.swift
//  social wand
//
//  Created by Cursor on 12/8/25.
//

import SwiftUI

struct HomeView: View {
    @State private var showContent = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let safeHeight = max(geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom, 1)
                let breakpoint = LayoutBreakpoint.forHeight(safeHeight)
                
                // Dynamic sizing
                let horizontalPadding = max(CGFloat(20), geo.size.width * 0.05)
                let logoSize: CGFloat = breakpoint == .veryCompact ? 50 : (breakpoint == .compact ? 56 : 60)
                let settingsIconSize: CGFloat = breakpoint == .veryCompact ? 22 : 26
                let settingsButtonSize: CGFloat = 44
                
                VStack(spacing: 0) {
                    // TOP BAR: Logo (absolute center) + Settings (absolute right)
                    ZStack {
                        // Wand Logo (absolutely centered)
                        HStack {
                            Spacer()
                            
                            Image("SocialWandLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoSize, height: logoSize)
                                .shadow(color: Color.white.opacity(0.1), radius: 12, y: 6)
                            
                            Spacer()
                        }
                        
                        // Settings button (absolute right)
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                showSettings = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: settingsButtonSize, height: settingsButtonSize)
                                    
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: settingsIconSize, weight: .medium))
                                        .foregroundStyle(AppBrand.purple)
                                }
                                .shadow(color: AppBrand.purple.opacity(0.3), radius: 8, y: 4)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .frame(height: max(logoSize, settingsButtonSize))
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)  // FIXED: Just 8pt below status bar
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
                    
                    // MAIN CONTENT AREA (empty for now)
                    ScrollView {
                        VStack(spacing: breakpoint == .veryCompact ? 20 : 28) {
                            // Title text
                            Text("Welcome to Social Wand")
                                .font(.system(size: breakpoint == .veryCompact ? 22 : (breakpoint == .compact ? 26 : 30), weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, breakpoint == .veryCompact ? 30 : 40)
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    }
                    
                    Spacer()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)  // Hide navigation bar completely
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettings"))) { _ in
                showSettings = true
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
}
