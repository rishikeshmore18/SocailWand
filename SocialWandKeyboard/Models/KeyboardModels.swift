//
//  KeyboardModels.swift
//  SocialWandKeyboard
//

import Foundation

// MARK: - Suggestion Model

struct KeyboardSuggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let index: Int
}

// MARK: - Generation State

enum GenerationState: Equatable {
    case idle
    case loading
    case loadingMore
    case success([KeyboardSuggestion])
    case error(String)
    
    var isLoading: Bool {
        switch self {
        case .loading, .loadingMore:
            return true
        default:
            return false
        }
    }
}

// MARK: - Text Context

struct TextContext {
    let fullText: String
    let selectedText: String?
    let hasSelection: Bool
    
    var textToImprove: String {
        hasSelection ? (selectedText ?? fullText) : fullText
    }
}


