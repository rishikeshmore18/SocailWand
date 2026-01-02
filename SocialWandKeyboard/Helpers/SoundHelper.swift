//
//  SoundHelper.swift
//  SocialWandKeyboard
//

import UIKit
import AudioToolbox

struct SoundHelper {
    private static let appGroupID = "group.rishi-more.social-wand"
    private static let soundKey = "SoundFeedbackEnabled"
    
    private static let keyTapSoundID: SystemSoundID = 1104
    private static let deleteSoundID: SystemSoundID = 1155
    
    static func playKeyTapSound() {
        guard isSoundEnabled() else { return }
        AudioServicesPlaySystemSound(keyTapSoundID)
    }
    
    static func playDeleteSound() {
        guard isSoundEnabled() else { return }
        AudioServicesPlaySystemSound(deleteSoundID)
    }
    
    static func playSystemSound(_ soundID: SystemSoundID) {
        guard isSoundEnabled() else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    private static func isSoundEnabled() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return false
        }
        return defaults.bool(forKey: soundKey)
    }
}

