//
//  HapticHelper.swift
//  SocialWandKeyboard
//

import UIKit

struct HapticHelper {
    private static let appGroupID = "group.rishi-more.social-wand"
    private static let hapticKey = "HapticFeedbackLevel"
    
    static func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
            return
        }
        
        let hapticLevel = defaults.string(forKey: hapticKey) ?? "soft"
        
        switch hapticLevel {
        case "soft":
            let adjustedStyle: UIImpactFeedbackGenerator.FeedbackStyle = (style == .heavy) ? .medium : .light
            UIImpactFeedbackGenerator(style: adjustedStyle).impactOccurred()
        case "strong":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "off":
            break
        default:
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
    
    static func triggerScrollHaptic() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        
        let hapticLevel = defaults.string(forKey: hapticKey) ?? "soft"
        
        switch hapticLevel {
        case "soft":
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case "strong":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "off":
            break
        default:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }
    
    static func isHapticsEnabled() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return true
        }
        let hapticLevel = defaults.string(forKey: hapticKey) ?? "soft"
        return hapticLevel != "off"
    }
}

