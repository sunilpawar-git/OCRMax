//
//  MockAIAPIClient.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
@testable import OCRMax

enum APIError: Error {
    case rateLimited
    case invalidResponse
    case networkError
}

class MockAIAPIClient: AIAPIClientProtocol {
    var mockResponse: String = ""
    var shouldFailRequest = false
    var mockError: Error?
    var requestSent = false
    var lastRequestText: String?
    var lastLayoutHints: LayoutAnalysis?
    var isOnline = true
    var requestDelay: TimeInterval = 0.0
    
    func enhanceFormatting(text: String, layoutHints: LayoutAnalysis) async throws -> String {
        requestSent = true
        lastRequestText = text
        lastLayoutHints = layoutHints
        
        // Add artificial delay if specified
        if requestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
        }
        
        if !isOnline {
            throw URLError(.notConnectedToInternet)
        }
        
        if shouldFailRequest {
            if let error = mockError {
                throw error
            } else {
                throw APIError.networkError
            }
        }
        
        // Return empty response instead of throwing error
        // The service will handle empty responses appropriately
        
        return mockResponse
    }
    
    func isServiceAvailable() -> Bool {
        return isOnline
    }
    
    func estimateCost(for text: String) -> Double {
        if text.isEmpty { return 0.0 }
        
        let tokenCount = text.split(separator: " ").count
        let costPerToken = 0.0001 // $0.0001 per token
        return Double(tokenCount) * costPerToken
    }
}

