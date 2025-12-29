//
//  SocialRater.swift
//  social wand
//

import Foundation

protocol SocialRaterType {
    func rate(incoming: String, reply: String, traits: [String]) async throws -> SocialRatingResponse
}

final class SocialRater: SocialRaterType {
    
    private let aiService = AIService.shared
    
    func rate(incoming: String, reply: String, traits: [String] = []) async throws -> SocialRatingResponse {
        
        if SocialRaterConfig.hardcodedMode {
            let score = Int.random(in: 3...5)
            return SocialRatingResponse(
                displayScoreText: "\(score)/10",
                headlineOverride: "You have poor social skills 😭",
                subline: "You scored lower than most people...",
                alternatives: [
                    "I feel the same way. I think it's best we give this a fresh start. What are you doing tomorrow at 5?",
                    "I've noticed that too. Any ideas on how we can make things better?"
                ]
            )
        }
        
        do {
            let response = try await aiService.rateSocialSkills(
                incoming: incoming,
                reply: reply,
                traits: traits
            )
            return response
            
        } catch let error as AIError {
            return SocialRatingResponse(
                displayScoreText: "—/10",
                headlineOverride: "You have poor social skills 😭",
                subline: error.localizedDescription,
                alternatives: [
                    "Please check your connection",
                    "Try again in a moment"
                ]
            )
        } catch {
            return SocialRatingResponse(
                displayScoreText: "—/10",
                headlineOverride: "You have poor social skills 😭",
                subline: "Something went wrong",
                alternatives: [
                    "Please try again",
                    "Check your connection"
                ]
            )
        }
    }
}

extension SocialRater {
    func rate(incoming: String, reply: String) async throws -> SocialRatingResponse {
        return try await rate(incoming: incoming, reply: reply, traits: [])
    }
}
