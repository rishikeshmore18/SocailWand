//
//  SettingsView.swift
//  social wand
//
//  Created by Cursor on 12/8/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    
    var body: some View {
        GeometryReader { geo in
            let safeHeight = max(geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom, 1)
            let breakpoint = LayoutBreakpoint.forHeight(safeHeight)
            
            // Dynamic sizing
            let horizontalPadding = max(CGFloat(20), geo.size.width * 0.05)
            
            VStack(spacing: 0) {
                // Title at the top (minimal spacing)
                Text("Settings")
                    .font(.system(size: breakpoint == .veryCompact ? 28 : (breakpoint == .compact ? 32 : 36), weight: .bold, design: .rounded))
                    .foregroundStyle(AppBrand.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)  // MINIMAL top spacing
                
                // Content area
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Settings coming soon...")
                            .font(.system(size: breakpoint == .veryCompact ? 16 : 18))
                            .foregroundStyle(AppBrand.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
                
                Spacer()
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)  // Hide default back button
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")  // Changed from "Home" to "Back"
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
