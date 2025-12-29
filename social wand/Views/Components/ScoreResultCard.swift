//
//  ScoreResultCard.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ScoreResultCard: View {
    let headlineOverride: String?
    let displayScoreText: String
    let subline: String
    let primaryButtonTitle: String
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                if let headline = headlineOverride {
                    Text(headline)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppBrand.textPrimary)
                        .multilineTextAlignment(.center)
                }
                
                Text(displayScoreText)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(AppBrand.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                
                Text(subline)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppBrand.textSecondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                    .frame(height: 20)
                
                Button(action: {
                    #if canImport(UIKit)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                    onDismiss()
                }) {
                    Text(primaryButtonTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppBrand.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppBrand.success)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .accessibilityLabel(Text(primaryButtonTitle))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppBrand.dim)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(AppBrand.cardBorder, lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 24, y: 12)
            )
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)
            
            Spacer()
        }
        .background(Color.black.opacity(0.85).ignoresSafeArea())
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

