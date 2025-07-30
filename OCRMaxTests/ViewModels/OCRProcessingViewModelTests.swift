//
//  OCRProcessingViewModelTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 29/07/25.
//

import XCTest
import UIKit
@testable import OCRMax

@MainActor
final class OCRProcessingViewModelTests: XCTestCase {
    
    var sut: OCRProcessingViewModel!
    var mockVisionOCRService: MockVisionOCRService!
    var mockTesseractOCRService: MockTesseractOCRService!
    var mockEnhancedVisionOCRService: MockEnhancedVisionOCRService!
    var mockPDFProcessor: MockPDFProcessor!
    var mockLayoutAnalyzer: MockLayoutAnalyzer!
    var mockSubscriptionManager: MockSubscriptionManager!
    var mockAIFormattingService: MockAIFormattingService!
    
    override func setUp() {
        super.setUp()
        mockVisionOCRService = MockVisionOCRService()
        mockTesseractOCRService = MockTesseractOCRService()
        mockEnhancedVisionOCRService = MockEnhancedVisionOCRService()
        mockPDFProcessor = MockPDFProcessor()
        mockLayoutAnalyzer = MockLayoutAnalyzer()
        mockSubscriptionManager = MockSubscriptionManager()
        mockAIFormattingService = MockAIFormattingService()
        
        sut = OCRProcessingViewModel(
            visionOCRService: mockVisionOCRService,
            tesseractOCRService: mockTesseractOCRService,
            enhancedVisionOCRService: mockEnhancedVisionOCRService,
            pdfProcessor: mockPDFProcessor,
            layoutAnalyzer: mockLayoutAnalyzer,
            subscriptionManager: mockSubscriptionManager,
            aiFormattingService: mockAIFormattingService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockVisionOCRService = nil
        mockTesseractOCRService = nil
        mockEnhancedVisionOCRService = nil
        mockPDFProcessor = nil
        mockLayoutAnalyzer = nil
        mockSubscriptionManager = nil
        mockAIFormattingService = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTemporaryTestFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_document.pdf")
        
        // Create a small test file
        let testData = "Test PDF content".data(using: .utf8)!
        try? testData.write(to: tempFile)
        
        return tempFile
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertTrue(sut.progressText.isEmpty)
        XCTAssertEqual(sut.selectedOCREngine, .vision)
        XCTAssertEqual(sut.selectedLanguage, "eng")
        XCTAssertEqual(sut.selectedFormattingLevel, .basic)
        XCTAssertEqual(sut.estimatedAICost, 0.0)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - OCR Engine Tests
    
    func testOCREngineEnumValues() {
        let engines = OCRProcessingViewModel.OCREngine.allCases
        XCTAssertEqual(engines.count, 3)
        
        XCTAssertTrue(engines.contains(.vision))
        XCTAssertTrue(engines.contains(.tesseract))
        XCTAssertTrue(engines.contains(.enhancedVision))
        
        XCTAssertEqual(OCRProcessingViewModel.OCREngine.vision.description, "Apple Vision")
        XCTAssertEqual(OCRProcessingViewModel.OCREngine.tesseract.description, "Tesseract OCR")
        XCTAssertEqual(OCRProcessingViewModel.OCREngine.enhancedVision.description, "Enhanced Vision")
    }
    
    func testSwitchOCREngine() {
        sut.switchOCREngine(to: .tesseract)
        XCTAssertEqual(sut.selectedOCREngine, .tesseract)
        
        sut.switchOCREngine(to: .enhancedVision)
        XCTAssertEqual(sut.selectedOCREngine, .enhancedVision)
    }
    
    // MARK: - Language Tests
    
    func testSetLanguage() {
        sut.setLanguage("deu")
        XCTAssertEqual(sut.selectedLanguage, "deu")
        
        sut.setLanguage("fra")
        XCTAssertEqual(sut.selectedLanguage, "fra")
    }
    
    // MARK: - Formatting Level Tests
    
    func testUpdateFormattingLevel() {
        sut.updateFormattingLevel(.enhanced)
        XCTAssertEqual(sut.selectedFormattingLevel, .enhanced)
        
        sut.updateFormattingLevel(.aiEnhanced)
        XCTAssertEqual(sut.selectedFormattingLevel, .aiEnhanced)
    }
    
    // MARK: - Image Processing Tests
    
    func testProcessImages() async {
        let testImages = [createTestImage(), createTestImage()]
        mockVisionOCRService.mockText = "Processed image text"
        
        sut.processImages(testImages)
        
        // Wait for processing to start and complete
        var iterations = 0
        let maxIterations = 100 // 10 seconds max wait
        
        // Wait for processing to start
        while !sut.isProcessing && iterations < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        // Wait for processing to complete
        iterations = 0
        while sut.isProcessing && iterations < maxIterations {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        XCTAssertEqual(mockVisionOCRService.recognizeTextFromImagesCallCount, 1, "OCR service should be called once")
        XCTAssertFalse(sut.isProcessing, "Processing should be complete")
        XCTAssertFalse(sut.extractedText.isEmpty, "Extracted text should not be empty")
    }
    
    func testProcessImageFile() async {
        let tempURL = createTemporaryTestFile()
        mockVisionOCRService.mockText = "Processed file text"
        
        sut.processImageFile(url: tempURL)
        
        // Wait for processing to start and complete
        var iterations = 0
        let maxIterations = 100 // 10 seconds max wait
        
        // Wait for processing to start
        while !sut.isProcessing && iterations < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        // Wait for processing to complete
        iterations = 0
        while sut.isProcessing && iterations < maxIterations {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        XCTAssertFalse(sut.isProcessing, "Processing should be complete")
    }
    
    // MARK: - PDF Processing Tests
    
    func testProcessPDFSmallFile() async {
        let tempURL = createTemporaryTestFile()
        mockPDFProcessor.mockPageCount = 5 // Small file
        mockVisionOCRService.mockText = "PDF processing text"
        
        sut.processPDF(url: tempURL)
        
        // Wait for processing to start and complete
        var iterations = 0
        let maxIterations = 100 // 10 seconds max wait
        
        // Wait for processing to start
        while !sut.isProcessing && iterations < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        // Wait for processing to complete
        iterations = 0
        while sut.isProcessing && iterations < maxIterations {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        XCTAssertEqual(mockPDFProcessor.extractImagesCallCount, 1, "PDF processor should be called once")
        XCTAssertFalse(sut.isProcessing, "Processing should be complete")
        XCTAssertFalse(sut.extractedText.isEmpty, "Extracted text should not be empty")
    }
    
    // MARK: - Reset State Tests
    
    func testResetProcessingState() {
        // Set some state
        sut.updateFormattingLevel(.enhanced)
        sut.setLanguage("deu")
        
        // Simulate processing state
        sut.resetProcessingState()
        
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertTrue(sut.progressText.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingError)
        
        // Settings should remain unchanged
        XCTAssertEqual(sut.selectedFormattingLevel, .enhanced)
        XCTAssertEqual(sut.selectedLanguage, "deu")
    }
    
    // MARK: - Enhanced Processing Tests
    
    func testGetProcessedTextBlocksInitiallyNil() {
        XCTAssertNil(sut.getProcessedTextBlocks())
    }
    
    func testGetLayoutAnalysisInitiallyNil() {
        XCTAssertNil(sut.getLayoutAnalysis())
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessingErrorHandling() async {
        let tempURL = createTemporaryTestFile()
        mockPDFProcessor.shouldSucceed = false
        mockPDFProcessor.mockError = OCRError.fileAccessDenied
        
        sut.processPDF(url: tempURL)
        
        // Wait for processing to start and complete
        var iterations = 0
        let maxIterations = 100 // 10 seconds max wait
        
        // Wait for processing to start
        while !sut.isProcessing && iterations < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        // Wait for processing to complete (should fail and stop processing)
        iterations = 0
        while sut.isProcessing && iterations < maxIterations {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        XCTAssertFalse(sut.isProcessing, "Processing should be complete")
        XCTAssertTrue(sut.showingError, "Error should be shown")
        XCTAssertNotNil(sut.errorMessage, "Error message should be set")
        XCTAssertTrue(sut.extractedText.isEmpty, "No text should be extracted on error")
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasExtractedText() async {
        XCTAssertFalse(sut.hasExtractedText)
        
        let testImages = [createTestImage()]
        mockVisionOCRService.mockText = "Test extracted text"
        
        sut.processImages(testImages)
        
        // Wait for processing to start and complete
        var iterations = 0
        let maxIterations = 100 // 10 seconds max wait
        
        // Wait for processing to start
        while !sut.isProcessing && iterations < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        // Wait for processing to complete
        iterations = 0
        while sut.isProcessing && iterations < maxIterations {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            iterations += 1
        }
        
        XCTAssertFalse(sut.extractedText.isEmpty, "Text should be extracted")
        XCTAssertTrue(sut.hasExtractedText, "Should have extracted text")
    }
}