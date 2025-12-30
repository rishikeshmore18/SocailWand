//
//  KeyboardAIService.swift
//  SocialWandKeyboard
//

import Foundation

// MARK: - AI Errors

enum KeyboardAIError: LocalizedError {
    case networkError
    case invalidResponse
    case serviceUnavailable(String)
    case invalidURL
    case noTraits

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Connection failed. Check your internet."
        case .invalidResponse:
            return "Received invalid response from AI"
        case .serviceUnavailable(let message):
            return message
        case .invalidURL:
            return "Invalid backend URL"
        case .noTraits:
            return "No traits selected. Please complete setup."
        }
    }
}

// MARK: - Response Model

struct AIResponse: Decodable {
    let displayScoreText: String
    let headlineOverride: String?
    let subline: String
    let alternatives: [String]
}

// MARK: - AI Service

final class KeyboardAIService {

    static let shared = KeyboardAIService()

    private let baseURL: String
    private let session: URLSession
    private let appGroupID = "group.rishi-more.social-wand"

    private init() {
        #if DEBUG
        // ⚠️ UPDATE THIS IP TO YOUR MAC'S IP
        self.baseURL = "http://192.168.1.248:3000"
        #else
        self.baseURL = "https://your-production-url.com"
        #endif

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Helpers

    private func parseBackendError(data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let msg = json["error"] as? String, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return msg
            }
            if let msg = json["message"] as? String, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return msg
            }
        }
        return nil
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }

    private func throwForHTTPFailure(endpoint: String, statusCode: Int, data: Data) throws {
        let backendMessage = parseBackendError(data: data)
        debugLog("🌐 [KeyboardAIService] \(endpoint) -> HTTP \(statusCode)")
        if let backendMessage = backendMessage {
            debugLog("🧾 [KeyboardAIService] backend error: \(backendMessage)")
            throw KeyboardAIError.serviceUnavailable(backendMessage)
        } else {
            throw KeyboardAIError.serviceUnavailable("Request failed (HTTP \(statusCode))")
        }
    }

    // MARK: - Public Methods

    func generateSuggestions(for userText: String, previousOutputs: [String]) async throws -> [String] {

        // ✅ Traits are OPTIONAL for keyboard. Do not block generation.
        let traits = loadTraits() ?? []

        guard let url = URL(string: "\(baseURL)/api/rate") else {
            throw KeyboardAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "incoming": "",
            "reply": userText,
            "traits": traits,
            "previousOutputs": previousOutputs
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw KeyboardAIError.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                try throwForHTTPFailure(endpoint: "/api/rate", statusCode: httpResponse.statusCode, data: data)
            }

            let decoder = JSONDecoder()
            let aiResponse = try decoder.decode(AIResponse.self, from: data)

            debugLog("✅ [KeyboardAIService] /api/rate -> \(aiResponse.alternatives.count) alternatives")
            return aiResponse.alternatives

        } catch let error as KeyboardAIError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw KeyboardAIError.networkError
            } else if error.code == .timedOut {
                throw KeyboardAIError.serviceUnavailable("Request timed out")
            } else {
                throw KeyboardAIError.networkError
            }
        } catch {
            debugLog("❌ [KeyboardAIService] /api/rate unexpected error: \(error)")
            throw KeyboardAIError.invalidResponse
        }
    }

    // MARK: - Tone Change

    func changeTone(of text: String, to tones: [String]) async throws -> [String] {

        guard let url = URL(string: "\(baseURL)/api/tone") else {
            throw KeyboardAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "text": text,
            "tones": tones
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw KeyboardAIError.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                try throwForHTTPFailure(endpoint: "/api/tone", statusCode: httpResponse.statusCode, data: data)
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let alternatives = json["alternatives"] as? [String], alternatives.count >= 2 {
                debugLog("✅ [KeyboardAIService] /api/tone -> \(alternatives.count) alternatives")
                return Array(alternatives.prefix(2))
            }

            // Fallback: old format { result: string }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? String {
                debugLog("⚠️ [KeyboardAIService] /api/tone old format detected, duplicating result")
                return [result, result]
            }

            throw KeyboardAIError.invalidResponse

        } catch let error as KeyboardAIError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw KeyboardAIError.networkError
            } else if error.code == .timedOut {
                throw KeyboardAIError.serviceUnavailable("Request timed out")
            } else {
                throw KeyboardAIError.networkError
            }
        } catch {
            debugLog("❌ [KeyboardAIService] /api/tone unexpected error: \(error)")
            throw KeyboardAIError.invalidResponse
        }
    }

    // MARK: - Length Change

    func changeLength(of text: String, to length: String, withTones tones: [String]?) async throws -> [String] {

        guard let url = URL(string: "\(baseURL)/api/length") else {
            throw KeyboardAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var requestBody: [String: Any] = [
            "text": text,
            "length": length
        ]

        if let tones = tones {
            requestBody["tones"] = tones
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw KeyboardAIError.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                try throwForHTTPFailure(endpoint: "/api/length", statusCode: httpResponse.statusCode, data: data)
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let alternatives = json["alternatives"] as? [String], alternatives.count >= 2 {
                debugLog("✅ [KeyboardAIService] /api/length -> \(alternatives.count) alternatives")
                return Array(alternatives.prefix(2))
            }

            // Fallback: old format { result: string }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? String {
                debugLog("⚠️ [KeyboardAIService] /api/length old format detected, duplicating result")
                return [result, result]
            }

            throw KeyboardAIError.invalidResponse

        } catch let error as KeyboardAIError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw KeyboardAIError.networkError
            } else if error.code == .timedOut {
                throw KeyboardAIError.serviceUnavailable("Request timed out")
            } else {
                throw KeyboardAIError.networkError
            }
        } catch {
            debugLog("❌ [KeyboardAIService] /api/length unexpected error: \(error)")
            throw KeyboardAIError.invalidResponse
        }
    }

    // MARK: - Photo Generation

    func generateMoreFromPhoto(photos: [String], context: String, previousMessages: [String], tones: [String]?, length: String?) async throws -> [String] {

        guard let url = URL(string: "\(baseURL)/api/upload") else {
            throw KeyboardAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var requestBody: [String: Any] = [
            "photos": photos,
            "context": context,
            "previousMessages": previousMessages
        ]

        if let tones = tones {
            requestBody["tones"] = tones
        }

        if let length = length {
            requestBody["length"] = length
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw KeyboardAIError.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                try throwForHTTPFailure(endpoint: "/api/upload", statusCode: httpResponse.statusCode, data: data)
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let alternatives = json["alternatives"] as? [String], alternatives.count >= 2 {
                    debugLog("✅ [KeyboardAIService] /api/upload -> \(alternatives.count) alternatives")
                    return Array(alternatives.prefix(2))
                }

                if let result = json["result"] as? String {
                    debugLog("⚠️ [KeyboardAIService] /api/upload single result format, duplicating")
                    return [result, result]
                }
            }

            throw KeyboardAIError.invalidResponse

        } catch let error as KeyboardAIError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw KeyboardAIError.networkError
            } else if error.code == .timedOut {
                throw KeyboardAIError.serviceUnavailable("Request timed out")
            } else {
                throw KeyboardAIError.networkError
            }
        } catch {
            debugLog("❌ [KeyboardAIService] /api/upload unexpected error: \(error)")
            throw KeyboardAIError.invalidResponse
        }
    }

    // MARK: - Reply Generation

    func generateReply(for incomingText: String, tones: [String]?, length: String?, previousOutputs: [String] = []) async throws -> [String] {
        
        guard let url = URL(string: "\(baseURL)/api/reply") else {
            throw KeyboardAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "text": incomingText,
            "previousOutputs": previousOutputs
        ]
        
        if let tones = tones, !tones.isEmpty {
            requestBody["tones"] = tones
        }
        
        if let length = length {
            requestBody["length"] = length.capitalized
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw KeyboardAIError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                try throwForHTTPFailure(endpoint: "/api/reply", statusCode: httpResponse.statusCode, data: data)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let alternatives = json["alternatives"] as? [String], alternatives.count >= 2 {
                debugLog("✅ [KeyboardAIService] /api/reply -> \(alternatives.count) alternatives")
                return Array(alternatives.prefix(2))
            }
            
            throw KeyboardAIError.invalidResponse
            
        } catch let error as KeyboardAIError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw KeyboardAIError.networkError
            } else if error.code == .timedOut {
                throw KeyboardAIError.serviceUnavailable("Request timed out")
            } else {
                throw KeyboardAIError.networkError
            }
        } catch {
            debugLog("❌ [KeyboardAIService] /api/reply unexpected error: \(error)")
            throw KeyboardAIError.invalidResponse
        }
    }

    // MARK: - Rewrite Generation

    func generateRewrite(for originalText: String, tones: [String]?, length: String?, previousOutputs: [String] = []) async throws -> [String] {
        
        guard let url = URL(string: "\(baseURL)/api/rewrite") else {
            throw KeyboardAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "text": originalText,
            "previousOutputs": previousOutputs
        ]
        
        if let tones = tones, !tones.isEmpty {
            requestBody["tones"] = tones
        }
        
        if let length = length {
            requestBody["length"] = length.capitalized
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw KeyboardAIError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                try throwForHTTPFailure(endpoint: "/api/rewrite", statusCode: httpResponse.statusCode, data: data)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let alternatives = json["alternatives"] as? [String], alternatives.count >= 2 {
                debugLog("✅ [KeyboardAIService] /api/rewrite -> \(alternatives.count) alternatives")
                return Array(alternatives.prefix(2))
            }
            
            throw KeyboardAIError.invalidResponse
            
        } catch let error as KeyboardAIError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw KeyboardAIError.networkError
            } else if error.code == .timedOut {
                throw KeyboardAIError.serviceUnavailable("Request timed out")
            } else {
                throw KeyboardAIError.networkError
            }
        } catch {
            debugLog("❌ [KeyboardAIService] /api/rewrite unexpected error: \(error)")
            throw KeyboardAIError.invalidResponse
        }
    }

    // MARK: - Private Methods

    private func loadTraits() -> [String]? {
        // ✅ Keyboard should not hard-fail if none exist.
        // We attempt to read existing app-group keys ONLY if they already exist.
        // If nothing exists, return [] (and continue).

        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            debugLog("⚠️ [KeyboardAIService] Unable to access app group defaults")
            return []
        }

        // Try common patterns without inventing new storage behavior:
        // If these keys don’t exist in your app, this returns [] and still works.
        let candidateKeys = [
            "selectedTraits",
            "selected_tones",
            "selectedTones",
            "tones",
            "traits"
        ]

        for key in candidateKeys {
            if let arr = defaults.array(forKey: key) as? [String], !arr.isEmpty {
                debugLog("📖 [KeyboardAIService] Loaded traits/tones from \(key): \(arr)")
                return arr
            }
        }

        debugLog("📖 [KeyboardAIService] No saved traits/tones found (using [])")
        return []
    }
}
