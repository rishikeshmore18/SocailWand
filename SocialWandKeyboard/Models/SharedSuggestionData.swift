//
//  SharedSuggestionData.swift
//  SocialWandKeyboard
//

import Foundation

/// Lightweight data structure for passing generated captions via App Group
struct SharedSuggestionData {
    /// The generated caption text
    let suggestion: String
    
    /// Timestamp when generated
    let timestamp: Date
    
    /// Source app (e.g., "instagram", "messages")
    let sourceApp: String?
    
    /// Preferences used (for reference)
    let tones: [String]?
    let length: String?
    
    // App Group suite name
    static let suiteName = "group.rishi-more.social-wand"
    
    // Keys for UserDefaults
    private static let suggestionKey = "GeneratedSuggestion"
    private static let hasNewKey = "HasNewSuggestion"
    private static let timestampKey = "SuggestionTimestamp"
    private static let sourceAppKey = "SuggestionSourceApp"
    
    /// Check if there's a new suggestion available
    static func hasNewSuggestion() -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return false }
        return defaults.bool(forKey: hasNewKey)
    }
    
    /// Retrieve the suggestion
    static func retrieve() -> SharedSuggestionData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let suggestion = defaults.string(forKey: suggestionKey),
              !suggestion.isEmpty else {
            return nil
        }
        
        let timestamp = defaults.object(forKey: timestampKey) as? Date ?? Date()
        let sourceApp = defaults.string(forKey: sourceAppKey)
        
        return SharedSuggestionData(
            suggestion: suggestion,
            timestamp: timestamp,
            sourceApp: sourceApp,
            tones: nil,
            length: nil
        )
    }
    
    /// Mark suggestion as consumed
    static func markAsConsumed() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(false, forKey: hasNewKey)
    }
    
    /// Clear all suggestion data
    static func clear() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: suggestionKey)
        defaults.removeObject(forKey: hasNewKey)
        defaults.removeObject(forKey: timestampKey)
        defaults.removeObject(forKey: sourceAppKey)
    }
}

