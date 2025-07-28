//
//  MockAIFormattingService.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
@testable import OCRMax

final class MockAIFormattingService: AIFormattingServiceProtocol {
    
    var mockFormattedText = "Formatted text result"
    var mockEstimatedCost: Double = 0.05
    var mockIsAvailable = true
    var mockError: Error?
    
    var enhanceFormattingCallCount = 0
    var estimatedCostCallCount = 0
    var isAvailableCallCount = 0
    
    var lastFormattingText: String?
    var lastLayoutHints: LayoutAnalysis?
    var lastCostEstimationText: String?
    
    func enhanceFormatting(text: String, layoutHints: LayoutAnalysis) async throws -> String {
        enhanceFormattingCallCount += 1
        lastFormattingText = text
        lastLayoutHints = layoutHints
        
        if let error = mockError {
            throw error
        }
        
        return mockFormattedText
    }
    
    func isAvailable() -> Bool {
        isAvailableCallCount += 1
        return mockIsAvailable
    }
    
    func estimatedCost(for text: String) -> Double {
        estimatedCostCallCount += 1
        lastCostEstimationText = text
        return mockEstimatedCost
    }
    
    func reset() {
        mockFormattedText = "Formatted text result"
        mockEstimatedCost = 0.05
        mockIsAvailable = true
        mockError = nil
        
        enhanceFormattingCallCount = 0
        estimatedCostCallCount = 0
        isAvailableCallCount = 0
        
        lastFormattingText = nil
        lastLayoutHints = nil
        lastCostEstimationText = nil
    }
}