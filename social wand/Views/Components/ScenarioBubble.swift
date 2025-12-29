//
//  ScenarioBubble.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

struct ScenarioBubble: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(AppBrand.textPrimary)
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppBrand.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppBrand.cardBorder, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.plusLighter)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 18, y: 6)
            )
    }
}

