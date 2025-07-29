//
//  MockOCRService.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import UIKit
import Vision
@testable import OCRMax

final class MockVisionOCRService: OCRServiceProtocol {
    
    var shouldSucceed = true
    var mockText = "Sample OCR text"
    var mockError = OCRError.processingFailed
    var recognizeTextCallCount = 0
    var recognizeTextFromImagesCallCount = 0
    var progressMessages: [String] = []
    
    func recognizeText(from image: UIImage) async throws -> String {
        recognizeTextCallCount += 1
        
        if shouldSucceed {
            return mockText
        } else {
            throw mockError
        }
    }
    
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String {
        recognizeTextFromImagesCallCount += 1
        
        if shouldSucceed {
            for (index, _) in images.enumerated() {
                let message = "Processing page \(index + 1) of \(images.count)"
                await MainActor.run {
                    progressMessages.append(message)
                }
                progressHandler(message)
                
                // Add a small delay to simulate processing
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            }
            
            let finalMessage = "OCR processing completed"
            await MainActor.run {
                progressMessages.append(finalMessage)
            }
            progressHandler(finalMessage)
            
            return mockText
        } else {
            throw mockError
        }
    }
    
    func setLanguage(_ language: String) {
        // Mock implementation - no-op
    }
    
    func getSupportedLanguages() -> [String] {
        return ["English"]
    }
    
    func reset() {
        shouldSucceed = true
        mockText = "Sample OCR text"
        mockError = OCRError.processingFailed
        recognizeTextCallCount = 0
        recognizeTextFromImagesCallCount = 0
        progressMessages.removeAll()
    }
}