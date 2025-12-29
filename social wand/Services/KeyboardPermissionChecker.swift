//
//  KeyboardPermissionChecker.swift
//  social wand
//
//  Created by Cursor on 11/14/25.
//

import UIKit
import SwiftUI

struct KeyboardPermissionChecker {
    // The keyboard bundle ID
    static let extensionIdentifier = "rishi-more.social-wand.keyboard"
    
    // AppStorage key for global keyboard ready state
    static let keyboardReadyKey = "keyboardReady"
    
    /// Check if the keyboard is enabled by the user
    /// Note: Uses KVC to access private "identifier" key - this is a known approach but may be fragile
    static func isKeyboardEnabled() -> Bool {
        UITextInputMode.activeInputModes
            .compactMap { $0.value(forKey: "identifier") as? String }
            .contains(where: { $0.contains(extensionIdentifier) })
    }
    
    /// Check if Full Access is enabled (reads flag written by keyboard extension)
    static func isFullAccessEnabled() -> Bool {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else { return false }
        return defaults.bool(forKey: SharedConstants.fullAccessKey)
    }
    
    /// Check if both keyboard is enabled AND full access is granted
    static func isReady() -> Bool {
        isKeyboardEnabled() && isFullAccessEnabled()
    }
    
    /// Refresh the global keyboard ready state and update @AppStorage
    /// This can be called from anywhere in the app, not just KeyboardSetupView
    static func refreshStatus() {
        let ready = isReady()
        UserDefaults.standard.set(ready, forKey: keyboardReadyKey)
    }
}

