//
//  SuggestionsViewModel.swift
//  SocialWandKeyboard
//

import SwiftUI
import Combine

// ✅ Operation type tracking for "Try Again"
enum LastOperation {
    case normalGeneration(text: String)
    case toneChange(text: String, tones: [String])
    case lengthChange(text: String, length: String, tones: [String]?)
    case photoGeneration(photos: [String], context: String, tones: [String]?, length: String?)
    case replyGeneration(incomingText: String, tones: [String]?, length: String?)
    case rewriteGeneration(originalText: String, tones: [String]?, length: String?)
}

final class SuggestionsViewModel: ObservableObject {
    
    @Published var state: GenerationState = .idle
    @Published var suggestions: [KeyboardSuggestion] = []
    
    // ✅ Track last operation for retry
    var lastOperation: LastOperation?
    
    // ✅ NEW: Current preferences (passed from KeyboardViewController)
    @Published var currentTones: [String] = []  // Tone IDs like ["assertive", "confident"]
    @Published var currentLength: String? = nil  // Length ID like "short", "medium", "long"
    
    var onApply: ((String) -> Void)?
    var onGenerateMore: (() -> Void)?
    var onShowKeyboard: (() -> Void)?
    var onRetry: (() -> Void)?  // ✅ NEW: Dedicated retry callback
    
    // ✅ NEW: Callback when user changes preferences in suggestions view
    var onPreferencesChanged: (([String], String?) -> Void)?  // (toneIDs, lengthID)
}
