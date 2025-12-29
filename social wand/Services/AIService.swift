//
//  AIService.swift
//  social wand
//

import Foundation

enum AIError: LocalizedError {
    case networkError
    case invalidResponse
    case serviceUnavailable(String)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .invalidResponse:
            return "Invalid response from AI"
        case .serviceUnavailable(let msg):
            return msg
        case .invalidURL:
            return "Invalid URL"
        }
    }
}

final class AIService {
    
    static let shared = AIService()
    
    private let baseURL: String
    private let session: URLSession
    
    private init() {
        #if DEBUG
        self.baseURL = "http://192.168.1.248:3000"
        #else
        self.baseURL = "https://your-production-url.com"
        #endif
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: config)
    }
    
    func rateSocialSkills(
        incoming: String,
        reply: String,
        traits: [String] = []
    ) async throws -> SocialRatingResponse {
        
        guard let url = URL(string: "\(baseURL)/api/rate") else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "incoming": incoming,
            "reply": reply,
            "traits": traits
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }
            
            if http.statusCode >= 500 {
                throw AIError.serviceUnavailable("Service unavailable")
            }
            
            if http.statusCode >= 400 {
                throw AIError.invalidResponse
            }
            
            guard http.statusCode == 200 else {
                throw AIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(SocialRatingResponse.self, from: data)
            
        } catch let error as AIError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                throw AIError.networkError
            } else if error.code == .timedOut {
                throw AIError.serviceUnavailable("Request timed out")
            } else {
                throw AIError.networkError
            }
        } catch {
            throw AIError.invalidResponse
        }
    }
}


