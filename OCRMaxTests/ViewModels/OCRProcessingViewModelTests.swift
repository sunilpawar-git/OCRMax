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
        
        // Wait for processing
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertEqual(mockVisionOCRService.recognizeTextFromImagesCallCount, 1)
        XCTAssertFalse(sut.isProcessing)
    }
    
    func testProcessImageFile() async {
        let tempURL = createTemporaryTestFile()
        mockVisionOCRService.mockText = "Processed file text"
        
        sut.processImageFile(url: tempURL)
        
        // Wait for processing
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertFalse(sut.isProcessing)
    }
    
    // MARK: - PDF Processing Tests
    
    func testProcessPDFSmallFile() async {
        let tempURL = createTemporaryTestFile()
        mockPDFProcessor.mockPageCount = 5 // Small file
        mockVisionOCRService.mockText = "PDF processing text"
        
        sut.processPDF(url: tempURL)
        
        // Wait for processing
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertEqual(mockPDFProcessor.extractImagesCallCount, 1)
        XCTAssertFalse(sut.isProcessing)
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
        
        // Wait for processing
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.showingError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasExtractedText() async {
        XCTAssertFalse(sut.hasExtractedText)
        
        let testImages = [createTestImage()]
        mockVisionOCRService.mockText = "Test extracted text"
        
        sut.processImages(testImages)
        
        // Wait for processing
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if !sut.extractedText.isEmpty {
            XCTAssertTrue(sut.hasExtractedText)
        }
    }
}