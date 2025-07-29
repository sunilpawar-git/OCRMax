//
//  MockPDFProcessor.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import UIKit
@testable import OCRMax

final class MockPDFProcessor: PDFProcessorProtocol {
    
    var shouldSucceed = true
    var mockImages: [UIImage] = []
    var mockPageCount = 1 {
        didSet {
            setupMockImages()
        }
    }
    var mockText = "Sample PDF text"
    var mockError = OCRError.unsupportedFormat
    var extractImagesCallCount = 0
    var extractImagesBatchCallCount = 0
    var getPageCountCallCount = 0
    var extractTextCallCount = 0
    var useBatchProcessor = false
    
    init() {
        setupMockImages()
    }
    
    func extractImages(from url: URL) throws -> [UIImage] {
        extractImagesCallCount += 1
        
        if shouldSucceed {
            return mockImages
        } else {
            throw mockError
        }
    }
    
    func extractImagesBatch(from url: URL, batchSize: Int, batchHandler: @escaping ([UIImage], Int, Int) throws -> Void) throws {
        extractImagesBatchCallCount += 1
        
        if shouldSucceed {
            let totalPages = mockImages.count
            let batches = stride(from: 0, to: totalPages, by: batchSize).map { start in
                Array(mockImages[start..<min(start + batchSize, totalPages)])
            }
            
            for (batchIndex, batch) in batches.enumerated() {
                try batchHandler(batch, batchIndex + 1, batches.count)
            }
        } else {
            throw mockError
        }
    }
    
    func getPageCount(from url: URL) -> Int {
        getPageCountCallCount += 1
        if shouldSucceed {
            return mockPageCount
        } else {
            return 0 // Return 0 for failed operations
        }
    }
    
    func extractTextFromPDF(url: URL) throws -> String {
        extractTextCallCount += 1
        
        if shouldSucceed {
            return mockText
        } else {
            throw mockError
        }
    }
    
    private func setupMockImages() {
        let image = createMockImage()
        mockImages = Array(repeating: image, count: max(mockPageCount, 2))
    }
    
    private func createMockImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.black.setStroke()
            context.stroke(CGRect(x: 10, y: 10, width: 80, height: 80))
        }
    }
    
    func reset() {
        shouldSucceed = true
        mockPageCount = 1
        mockText = "Sample PDF text"
        mockError = OCRError.unsupportedFormat
        extractImagesCallCount = 0
        extractImagesBatchCallCount = 0
        getPageCountCallCount = 0
        extractTextCallCount = 0
        useBatchProcessor = false
        setupMockImages()
    }
}