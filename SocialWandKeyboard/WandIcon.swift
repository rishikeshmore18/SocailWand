import SwiftUI
import UIKit

// Color hex extension - MUST be at the top
extension Color {
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

struct WandIcon: View {
    let isExpanded: Bool
    @Environment(\.colorScheme) var colorScheme  // Detect light/dark mode
    
    var body: some View {
        ZStack {
            if isExpanded {
                // X icon (adaptive colors for light/dark mode)
                Circle()
                    .fill(adaptiveBackgroundColor.opacity(0.3))
                    .frame(width: 44, height: 44)  // Increased from 32
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))  // Increased from 14
                            .foregroundColor(adaptiveForegroundColor)
                    )
            } else {
                // Wand icon with gray background circle
                ZStack {
                    // Solid gray circle background (KEEP THIS)
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    // SVG wand icon - preserve original colors (purple/teal gradient)
                    // Doubled size: 28 -> 56
                    if let uiImage = UIImage(named: "WandIcon") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .renderingMode(.original)  // Preserve original gradient colors
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                    } else {
                        // Fallback if asset not found (debug)
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 40))  // Also doubled: 20 -> 40
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .rotationEffect(.degrees(isExpanded ? 360 : 0))
    }
    
    // Adaptive colors for light/dark mode
    private var adaptiveBackgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var adaptiveForegroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
}
