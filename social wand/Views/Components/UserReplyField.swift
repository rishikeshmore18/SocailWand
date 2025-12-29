//
//  UserReplyField.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct UserReplyField: View {
    @Binding var text: String
    let placeholder: String
    let focus: FocusState<Bool>.Binding
    let shakeToken: Int
    
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        textField
            .focused(focus)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(AppBrand.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppBrand.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppBrand.cardBorder, lineWidth: 1)
                    )
            )
            .offset(x: shakeOffset)
            .onChange(of: shakeToken) { _, _ in
                triggerShake()
            }
    }

    @ViewBuilder
    private var textField: some View {
        #if os(iOS)
        TextField(placeholder, text: $text, axis: .vertical)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .lineLimit(3...6)
        #else
        TextField(placeholder, text: $text)
        #endif
    }
    
    func triggerShake() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
            shakeOffset = -10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                shakeOffset = 10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                shakeOffset = 0
            }
        }
    }
}

