//
//  MockEnhancedVisionOCRService.swift
//  OCRMaxTests
//
//  Created by Claude on 29/07/25.
//

import Foundation
import UIKit
@testable import OCRMax

final class MockEnhancedVisionOCRService: EnhancedOCRServiceProtocol {
    
    // MARK: - Call Tracking
    var recognizeTextCallCount = 0
    var recognizeTextFromImagesCallCount = 0
    var recognizeTextBlocksCallCount = 0
    var recognizeTextBlocksFromImagesCallCount = 0
    var getSupportedLanguagesCallCount = 0
    var setLanguageCallCount = 0
    
    // MARK: - Mock Data
    var mockText = "Mock OCR result"
    var mockTextBlocks: [TextBlock] = []
    var mockSupportedLanguages = ["eng", "deu", "fra", "spa"]
    var shouldSucceed = true
    var mockError: Error?
    var processingDelay: TimeInterval = 0.1
    
    // MARK: - Captured Parameters
    var lastSetLanguage: String?
    var lastProcessedImages: [UIImage] = []
    var lastProgressHandler: ((String) -> Void)?
    
    // MARK: - OCRServiceProtocol Methods
    
    func recognizeText(from image: UIImage) async throws -> String {
        recognizeTextCallCount += 1
        
        if !shouldSucceed, let error = mockError {
            throw error
        }
        
        try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        return mockText
    }
    
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String {
        recognizeTextFromImagesCallCount += 1
        lastProcessedImages = images
        lastProgressHandler = progressHandler
        
        if !shouldSucceed, let error = mockError {
            throw error
        }
        
        // Simulate progress updates
        for (index, _) in images.enumerated() {
            let progress = "Processing image \(index + 1) of \(images.count)"
            await MainActor.run {
                progressHandler(progress)
            }
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }
        
        await MainActor.run {
            progressHandler("OCR processing completed")
        }
        
        return mockText
    }
    
    func getSupportedLanguages() -> [String] {
        getSupportedLanguagesCallCount += 1
        return mockSupportedLanguages
    }
    
    func setLanguage(_ language: String) {
        setLanguageCallCount += 1
        lastSetLanguage = language
    }
    
    // MARK: - EnhancedOCRServiceProtocol Methods
    
    func recognizeTextBlocks(from image: UIImage) async throws -> [TextBlock] {
        recognizeTextBlocksCallCount += 1
        
        if !shouldSucceed, let error = mockError {
            throw error
        }
        
        try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        
        // Return mock text blocks if provided, otherwise create default ones
        if !mockTextBlocks.isEmpty {
            return mockTextBlocks
        }
        
        // Create default mock text blocks
        return [
            TextBlock(
                text: mockText,
                boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
                confidence: 0.95
            )
        ]
    }
    
    func recognizeTextBlocks(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> [TextBlock] {
        recognizeTextBlocksFromImagesCallCount += 1
        lastProcessedImages = images
        lastProgressHandler = progressHandler
        
        if !shouldSucceed, let error = mockError {
            throw error
        }
        
        var allTextBlocks: [TextBlock] = []
        
        // Simulate progress updates
        for (index, _) in images.enumerated() {
            let progress = "Processing image \(index + 1) of \(images.count) for text blocks"
            await MainActor.run {
                progressHandler(progress)
            }
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
            
            // Add mock text blocks for each image
            if !mockTextBlocks.isEmpty {
                allTextBlocks.append(contentsOf: mockTextBlocks)
            } else {
                // Create default mock text block for each image
                let textBlock = TextBlock(
                    text: "\(mockText) - Image \(index + 1)",
                    boundingBox: CGRect(x: 0, y: CGFloat(index * 25), width: 100, height: 20),
                    confidence: 0.95
                )
                allTextBlocks.append(textBlock)
            }
        }
        
        await MainActor.run {
            progressHandler("Text block extraction completed")
        }
        
        return allTextBlocks
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        recognizeTextCallCount = 0
        recognizeTextFromImagesCallCount = 0
        recognizeTextBlocksCallCount = 0
        recognizeTextBlocksFromImagesCallCount = 0
        getSupportedLanguagesCallCount = 0
        setLanguageCallCount = 0
        
        mockText = "Mock OCR result"
        mockTextBlocks = []
        shouldSucceed = true
        mockError = nil
        processingDelay = 0.1
        
        lastSetLanguage = nil
        lastProcessedImages = []
        lastProgressHandler = nil
    }
    
    func setMockTextBlocks(_ textBlocks: [TextBlock]) {
        mockTextBlocks = textBlocks
    }
    
    func simulateError(_ error: Error) {
        shouldSucceed = false
        mockError = error
    }
    
    func simulateProcessingDelay(_ delay: TimeInterval) {
        processingDelay = delay
    }
}