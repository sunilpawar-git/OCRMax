//
//  AIFormattingService.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation

enum APIError: Error {
    case rateLimited
    case invalidResponse
    case networkError
}

final class AIFormattingService: AIFormattingServiceProtocol {
    
    private let apiClient: AIAPIClientProtocol
    private let subscriptionManager: SubscriptionManagerProtocol
    private let maxTextLength = 50_000 // Characters
    private let costPerToken = 0.0001 // $0.0001 per token estimate
    
    init(apiClient: AIAPIClientProtocol = OpenAIAPIClient(),
         subscriptionManager: SubscriptionManagerProtocol) {
        self.apiClient = apiClient
        self.subscriptionManager = subscriptionManager
    }
    
    // MARK: - AIFormattingServiceProtocol
    
    func enhanceFormatting(text: String, layoutHints: LayoutAnalysis) async throws -> String {
        // Check subscription access
        guard subscriptionManager.canUseFeature(.aiFormatting) else {
            throw OCRError.subscriptionRequired
        }
        
        // Validate service availability
        guard isAvailable() else {
            throw OCRError.aiServiceUnavailable
        }
        
        // Validate text length
        guard !text.isEmpty else {
            throw OCRError.noTextFound
        }
        
        guard text.count <= maxTextLength else {
            // For very large texts, split into chunks
            return try await processLargeText(text, layoutHints: layoutHints)
        }
        
        do {
            let enhancedText = try await apiClient.enhanceFormatting(text: text, layoutHints: layoutHints)
            
            guard !enhancedText.isEmpty else {
                throw OCRError.processingFailed
            }
            
            return enhancedText
            
        } catch is URLError {
            throw OCRError.aiServiceUnavailable
        } catch APIError.rateLimited {
            throw OCRError.aiServiceUnavailable
        } catch OCRError.processingFailed {
            throw OCRError.processingFailed
        } catch {
            throw OCRError.aiServiceUnavailable
        }
    }
    
    func isAvailable() -> Bool {
        return apiClient.isServiceAvailable()
    }
    
    func estimatedCost(for text: String) -> Double {
        return apiClient.estimateCost(for: text)
    }
    
    // MARK: - Private Methods
    
    private func processLargeText(_ text: String, layoutHints: LayoutAnalysis) async throws -> String {
        let chunkSize = maxTextLength / 2 // Use smaller chunks for large text
        let chunks = text.chunked(into: chunkSize)
        var processedChunks: [String] = []
        
        for chunk in chunks {
            let processedChunk = try await apiClient.enhanceFormatting(text: chunk, layoutHints: layoutHints)
            processedChunks.append(processedChunk)
        }
        
        return processedChunks.joined(separator: "\n\n")
    }
}

// MARK: - AI API Client Protocol

protocol AIAPIClientProtocol {
    func enhanceFormatting(text: String, layoutHints: LayoutAnalysis) async throws -> String
    func isServiceAvailable() -> Bool
    func estimateCost(for text: String) -> Double
}

// MARK: - OpenAI Implementation

final class OpenAIAPIClient: AIAPIClientProtocol {
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-3.5-turbo"
    private let session: URLSession
    
    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey ?? Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
        self.session = session
    }
    
    func enhanceFormatting(text: String, layoutHints: LayoutAnalysis) async throws -> String {
        let prompt = buildPrompt(text: text, layoutHints: layoutHints)
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert document formatter. Enhance the formatting of OCR text based on layout analysis to recreate the original document structure."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": min(4000, text.count / 2),
            "temperature": 0.3
        ]
        
        guard let url = URL(string: baseURL) else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        if httpResponse.statusCode == 429 {
            throw APIError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw APIError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func isServiceAvailable() -> Bool {
        return !apiKey.isEmpty
    }
    
    func estimateCost(for text: String) -> Double {
        if text.isEmpty { return 0.0 }
        
        // Rough token estimation: ~4 characters per token
        let inputTokens = text.count / 4
        let outputTokens = inputTokens / 2 // Assume output is half the input
        let totalTokens = inputTokens + outputTokens
        
        return Double(totalTokens) * 0.0001
    }
    
    private func buildPrompt(text: String, layoutHints: LayoutAnalysis) -> String {
        var prompt = "Please enhance the formatting of this OCR text to recreate the original document structure:\n\n"
        prompt += "TEXT TO FORMAT:\n\(text)\n\n"
        prompt += "LAYOUT ANALYSIS:\n"
        
        // Add column information
        if layoutHints.columns.count > 1 {
            prompt += "- Document has \(layoutHints.columns.count) columns\n"
        }
        
        // Add text group information
        let headers = layoutHints.textGroups.filter { $0.groupType == .header }
        if !headers.isEmpty {
            prompt += "- Document contains \(headers.count) headers\n"
        }
        
        let lists = layoutHints.textGroups.filter { $0.groupType == .list }
        if !lists.isEmpty {
            prompt += "- Document contains \(lists.count) list sections\n"
        }
        
        let tables = layoutHints.textGroups.filter { $0.groupType == .table }
        if !tables.isEmpty {
            prompt += "- Document contains \(tables.count) table sections\n"
        }
        
        // Add spacing information
        prompt += "- Average line spacing: \(layoutHints.spacing.averageLineSpacing) points\n"
        prompt += "- Average paragraph spacing: \(layoutHints.spacing.paragraphSpacing) points\n"
        
        prompt += "\nPlease return the formatted text with:\n"
        prompt += "- Proper headers (use # for main headers, ## for subheaders)\n"
        prompt += "- Correct paragraph breaks and spacing\n"
        prompt += "- Properly formatted lists with bullet points or numbers\n"
        prompt += "- Table formatting where appropriate\n"
        prompt += "- Maintain the original content without adding or removing information\n"
        
        return prompt
    }
}