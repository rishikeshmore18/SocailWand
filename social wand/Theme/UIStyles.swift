//
//  UIStyles.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Brand Colors

enum AppBrand {
    static let purple = Color(hex: 0x8B5CF6)
    static let purpleDark = Color(hex: 0x7C3AED)
    static let amber = Color(hex: 0xF59E0B)
    static let success = Color(hex: 0x22C55E)
    static let cardBackground = Color(hex: 0x121212)
    static let cardBorder = Color(hex: 0x262626)
    static let iconBackground = Color.white.opacity(0.04)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xC8C8C8)
    static let textHint = Color.white.opacity(0.5)
    static let dim = Color(hex: 0x0B0B0B)
}

