//
//  MockTesseractOCRService.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import UIKit
@testable import OCRMax

final class MockTesseractOCRService: OCRServiceProtocol {
    
    var shouldSucceed = true
    var mockText = "Mock Tesseract OCR Result"
    var recognizeTextCallCount = 0
    var recognizeTextFromImagesCallCount = 0
    var lastProgressUpdates: [String] = []
    
    func recognizeText(from image: UIImage) async throws -> String {
        recognizeTextCallCount += 1
        
        if shouldSucceed {
            return mockText
        } else {
            throw OCRError.processingFailed
        }
    }
    
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String {
        recognizeTextFromImagesCallCount += 1
        lastProgressUpdates.removeAll()
        
        if shouldSucceed {
            var allText = ""
            
            for (index, _) in images.enumerated() {
                let progressMessage = "Processing page \(index + 1) of \(images.count) with Tesseract..."
                progressHandler(progressMessage)
                lastProgressUpdates.append(progressMessage)
                
                allText += "\(mockText) Page \(index + 1)\n\n"
                
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            
            return allText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let errorMessage = "Failed to process images with Tesseract"
            progressHandler(errorMessage)
            lastProgressUpdates.append(errorMessage)
            throw OCRError.processingFailed
        }
    }
    
    func setLanguage(_ language: String) {
        // Mock implementation - no-op
    }
    
    func getSupportedLanguages() -> [String] {
        return ["eng", "fra", "deu", "spa"]
    }
    
    func reset() {
        shouldSucceed = true
        mockText = "Mock Tesseract OCR Result"
        recognizeTextCallCount = 0
        recognizeTextFromImagesCallCount = 0
        lastProgressUpdates.removeAll()
    }
}