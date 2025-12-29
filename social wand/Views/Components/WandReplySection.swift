//
//  WandReplySection.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

struct WandReplySection: View {
    let alternatives: [String]
    
    @State private var headerVisible = false
    @State private var visibleAlternatives: Set<Int> = []
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down")
                    .font(SwiftUI.Font.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppBrand.textPrimary)
                
                Text("Wand Reply")
                    .font(SwiftUI.Font.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppBrand.textPrimary)
                
                Image(systemName: "arrow.down")
                    .font(SwiftUI.Font.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppBrand.textPrimary)
            }
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35)) {
                    headerVisible = true
                }
            }
            
            ForEach(Array(alternatives.enumerated()), id: \.offset) { index, alt in
                VStack(spacing: 0) {
                    if index > 0 {
                        Text("OR")
                            .font(SwiftUI.Font.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppBrand.textSecondary)
                            .padding(.vertical, 16)
                            .accessibilityLabel(Text("Alternative option"))
                    }
                    
                    Text(verbatim: alt)
                        .foregroundStyle(AppBrand.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppBrand.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(AppBrand.cardBorder, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 18, y: 6)
                        )
                        .opacity(visibleAlternatives.contains(index) ? 1 : 0)
                        .offset(y: visibleAlternatives.contains(index) ? 0 : 12)
                        .onAppear {
                            let delay = Double(index) * 0.12
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    _ = visibleAlternatives.insert(index)
                                }
                            }
                        }
                        .accessibilityLabel(Text("Suggested reply \(index + 1): \(alt)"))
                }
                .font(SwiftUI.Font.system(size: 15, weight: .medium))
            }
        }
    }
}

