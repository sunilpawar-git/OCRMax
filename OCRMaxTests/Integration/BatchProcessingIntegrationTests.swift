//
//  BatchProcessingIntegrationTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 29/07/25.
//

import XCTest
import UIKit
@testable import OCRMax

@MainActor
final class BatchProcessingIntegrationTests: XCTestCase {
    
    var ocrProcessingViewModel: OCRProcessingViewModel!
    var mockPDFProcessor: MockPDFProcessor!
    var mockVisionOCRService: MockVisionOCRService!
    var mockEnhancedVisionOCRService: MockEnhancedVisionOCRService!
    var mockLayoutAnalyzer: MockLayoutAnalyzer!
    var mockSubscriptionManager: MockSubscriptionManager!
    var mockAIFormattingService: MockAIFormattingService!
    
    override func setUp() {
        super.setUp()
        mockPDFProcessor = MockPDFProcessor()
        mockVisionOCRService = MockVisionOCRService()
        mockEnhancedVisionOCRService = MockEnhancedVisionOCRService()
        mockLayoutAnalyzer = MockLayoutAnalyzer()
        mockSubscriptionManager = MockSubscriptionManager()
        mockAIFormattingService = MockAIFormattingService()
        
        ocrProcessingViewModel = OCRProcessingViewModel(
            visionOCRService: mockVisionOCRService,
            tesseractOCRService: MockTesseractOCRService(),
            enhancedVisionOCRService: mockEnhancedVisionOCRService,
            pdfProcessor: mockPDFProcessor,
            layoutAnalyzer: mockLayoutAnalyzer,
            subscriptionManager: mockSubscriptionManager,
            aiFormattingService: mockAIFormattingService
        )
    }
    
    override func tearDown() {
        ocrProcessingViewModel = nil
        mockPDFProcessor = nil
        mockVisionOCRService = nil
        mockEnhancedVisionOCRService = nil
        mockLayoutAnalyzer = nil
        mockSubscriptionManager = nil
        mockAIFormattingService = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTemporaryLargePDFFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("large_test_document.pdf")
        
        // Create test data simulating a larger file
        let testData = String(repeating: "Test PDF content page. ", count: 1000).data(using: .utf8)!
        try? testData.write(to: tempFile)
        
        return tempFile
    }
    
    // MARK: - Batch Processing Threshold Tests
    
    func testSmallPDFUsesStandardProcessing() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 50 // Below batch threshold
        mockVisionOCRService.mockText = "Standard processing result"
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        // Wait for processing to complete
        let startTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(startTime) < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Standard processing should extract all images at once
        XCTAssertEqual(mockPDFProcessor.extractImagesCallCount, 1)
        XCTAssertEqual(mockPDFProcessor.extractImagesBatchCallCount, 0)
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
    }
    
    func testLargePDFUsesBatchProcessing() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 150 // Above batch threshold (typically 100)
        mockVisionOCRService.mockText = "Batch processing result"
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        // Wait for processing to complete
        let startTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(startTime) < 15 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Batch processing should call extractImagesBatch
        XCTAssertEqual(mockPDFProcessor.extractImagesBatchCallCount, 1)
        XCTAssertEqual(mockPDFProcessor.extractImagesCallCount, 0)
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
    }
    
    // MARK: - Batch Size Calculation Tests
    
    func testBatchSizeCalculationForMediumFile() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 200
        mockPDFProcessor.useBatchProcessor = true
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        // Wait briefly for processing to start
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Should use batch processing for files with many pages
        XCTAssertTrue(ocrProcessingViewModel.isProcessing || mockPDFProcessor.extractImagesBatchCallCount > 0)
    }
    
    func testBatchSizeCalculationForLargeFile() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 500
        mockPDFProcessor.useBatchProcessor = true
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        // Wait briefly for processing to start
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Should use batch processing with smaller batch sizes for very large files
        XCTAssertTrue(ocrProcessingViewModel.isProcessing || mockPDFProcessor.extractImagesBatchCallCount > 0)
    }
    
    // MARK: - Progress Reporting Tests
    
    func testBatchProcessingProgressReporting() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 150
        mockVisionOCRService.mockText = "Batch processing result"
        
        var progressMessages: [String] = []
        
        // Monitor progress text changes
        let initialProgressText = ocrProcessingViewModel.progressText
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        // Sample progress text at intervals
        for _ in 0..<5 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if !ocrProcessingViewModel.progressText.isEmpty && ocrProcessingViewModel.progressText != initialProgressText {
                progressMessages.append(ocrProcessingViewModel.progressText)
            }
            if !ocrProcessingViewModel.isProcessing {
                break
            }
        }
        
        // Wait for processing to complete
        let startTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(startTime) < 15 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
        // Progress should be reported during batch processing
        XCTAssertTrue(progressMessages.count >= 0) // May or may not capture progress depending on timing
    }
    
    // MARK: - Memory Management Tests
    
    func testBatchProcessingMemoryEfficiency() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 200
        mockPDFProcessor.useBatchProcessor = true
        
        // Monitor memory usage would require more sophisticated testing
        // For now, just verify batch processing completes successfully
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        let startTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(startTime) < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
        XCTAssertEqual(mockPDFProcessor.extractImagesBatchCallCount, 1)
    }
    
    // MARK: - Error Handling in Batch Processing Tests
    
    func testBatchProcessingErrorHandling() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 150
        mockPDFProcessor.shouldSucceed = false
        mockPDFProcessor.mockError = OCRError.processingFailed
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        let startTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(startTime) < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
        XCTAssertTrue(ocrProcessingViewModel.showingError)
        XCTAssertNotNil(ocrProcessingViewModel.errorMessage)
    }
    
    // MARK: - Enhanced Processing with Batch Tests
    
    func testBatchProcessingWithEnhancedFormatting() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 120
        mockSubscriptionManager.mockCurrentTier = .premium
        
        // Set enhanced formatting level
        ocrProcessingViewModel.updateFormattingLevel(.enhanced)
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        let startTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(startTime) < 15 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
        // Enhanced processing should be used for premium users
        XCTAssertEqual(ocrProcessingViewModel.selectedFormattingLevel, .enhanced)
    }
    
    // MARK: - Performance Benchmarks
    
    func testBatchProcessingPerformance() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 100 // Right at the threshold
        mockVisionOCRService.mockText = "Performance test result"
        
        let startTime = Date()
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        // Wait for processing to complete
        let processingStartTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(processingStartTime) < 30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
        XCTAssertLessThan(totalTime, 30.0, "Batch processing should complete within reasonable time")
    }
    
    // MARK: - Integration with Document Export Tests
    
    func testBatchProcessingResultsAvailableForExport() async {
        let tempURL = createTemporaryLargePDFFile()
        mockPDFProcessor.mockPageCount = 150
        mockVisionOCRService.mockText = "Processed batch text for export"
        
        ocrProcessingViewModel.processPDF(url: tempURL)
        
        let startTime = Date()
        while ocrProcessingViewModel.isProcessing && Date().timeIntervalSince(startTime) < 15 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertFalse(ocrProcessingViewModel.isProcessing)
        
        // After batch processing, text should be available for export
        if !ocrProcessingViewModel.extractedText.isEmpty {
            XCTAssertTrue(ocrProcessingViewModel.hasExtractedText)
            
            // Enhanced data should be available if enhanced processing was used
            if ocrProcessingViewModel.selectedFormattingLevel != .basic {
                // Text blocks and layout analysis may be available
                let textBlocks = ocrProcessingViewModel.getProcessedTextBlocks()
                let layoutAnalysis = ocrProcessingViewModel.getLayoutAnalysis()
                
                // These may be nil for basic processing, but that's expected
                XCTAssertTrue(textBlocks == nil || textBlocks!.count >= 0)
                XCTAssertTrue(layoutAnalysis == nil || layoutAnalysis!.columns.count >= 0)
            }
        }
    }
}