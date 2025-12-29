//
//  SocialRatingModels.swift
//  social wand
//
//  Created by Cursor on 11/12/25.
//

import Foundation

struct SocialRaterConfig {
    static let hardcodedMode: Bool = true
}

struct SocialRatingResponse: Decodable {
    let displayScoreText: String
    let headlineOverride: String?
    let subline: String
    let alternatives: [String]
}

enum TestStage {
    case input
    case evaluating
    case showScore
    case showAlternatives
}

