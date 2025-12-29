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
}

final class SuggestionsViewModel: ObservableObject {
    
    @Published var state: GenerationState = .idle
    @Published var suggestions: [KeyboardSuggestion] = []
    
    // ✅ Track last operation for retry
    var lastOperation: LastOperation?
    
    var onApply: ((String) -> Void)?
    var onGenerateMore: (() -> Void)?
    var onShowKeyboard: (() -> Void)?
    var onRetry: (() -> Void)?  // ✅ NEW: Dedicated retry callback
}
