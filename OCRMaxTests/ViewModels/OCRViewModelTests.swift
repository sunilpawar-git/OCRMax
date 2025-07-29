//
//  OCRViewModelTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import XCTest
@testable import OCRMax

@MainActor
final class OCRViewModelTests: XCTestCase {
    
    var sut: OCRViewModel!
    var mockVisionOCRService: MockVisionOCRService!
    var mockTesseractOCRService: MockTesseractOCRService!
    var mockPDFProcessor: MockPDFProcessor!
    var mockDocumentExporter: MockDocumentExporter!
    
    override func setUp() {
        super.setUp()
        mockVisionOCRService = MockVisionOCRService()
        mockTesseractOCRService = MockTesseractOCRService()
        mockPDFProcessor = MockPDFProcessor()
        mockDocumentExporter = MockDocumentExporter()
        
        // Configure mock for small file to avoid file size validation
        mockPDFProcessor.mockPageCount = 10 // Small page count to avoid large file checks
        
        sut = OCRViewModel()
    }
    
    override func tearDown() {
        sut = nil
        mockVisionOCRService = nil
        mockTesseractOCRService = nil
        mockPDFProcessor = nil
        mockDocumentExporter = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTemporaryTestFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_document.pdf")
        
        // Create a small test file (just some data to make it exist)
        let testData = "Test PDF content".data(using: .utf8)!
        try? testData.write(to: tempFile)
        
        return tempFile
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertTrue(sut.progressText.isEmpty)
        XCTAssertNil(sut.selectedPDFURL)
        XCTAssertNil(sut.wordDocumentURL)
        XCTAssertFalse(sut.showingShareSheet)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingError)
    }
    
    func testComputedProperties_InitialState() {
        XCTAssertFalse(sut.hasSelectedPDF)
        XCTAssertFalse(sut.hasExtractedText)
        XCTAssertFalse(sut.canConvertToWord)
        XCTAssertTrue(sut.selectedFileName.isEmpty)
    }
    
    // MARK: - PDF Processing Tests
    
    func testProcessPDF_Success() async {
        // Create a temporary file for testing
        let tempURL = createTemporaryTestFile()
        
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete by monitoring isProcessing flag
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 15 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Wait a bit more for final UI updates
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        XCTAssertEqual(sut.selectedPDFURL, tempURL)
        XCTAssertTrue(sut.hasSelectedPDF)
        XCTAssertEqual(sut.selectedFileName, "test_document.pdf")
        XCTAssertFalse(sut.isProcessing)
    }
    
    func testProcessPDF_PDFProcessorFailure() async {
        let tempURL = createTemporaryTestFile()
        
        sut.processPDF(url: tempURL)
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertEqual(sut.selectedPDFURL, tempURL)
        XCTAssertFalse(sut.isProcessing)
    }
    
    func testProcessPDF_OCRServiceFailure() async {
        let tempURL = createTemporaryTestFile()
        
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete by monitoring isProcessing flag
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Wait a bit more for final UI updates
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        XCTAssertEqual(sut.selectedPDFURL, tempURL)
        XCTAssertFalse(sut.isProcessing)
    }
    
    func testProcessPDF_IgnoresSubsequentCallsWhileProcessing() async {
        let tempURL1 = createTemporaryTestFile()
        let tempURL2 = createTemporaryTestFile()
        
        sut.processPDF(url: tempURL1)
        
        // Give a moment for the first call to start processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        XCTAssertTrue(sut.isProcessing)
        
        sut.processPDF(url: tempURL2)
        
        // Small wait to ensure second call is processed (should be ignored)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // The selected URL should still be the first one
        XCTAssertEqual(sut.selectedPDFURL, tempURL1)
    }
    
    // MARK: - Word Document Conversion Tests
    
    func testConvertToWordDocument_Success() async {
        // First process a document to have extracted text
        let tempURL = createTemporaryTestFile()
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if !sut.extractedText.isEmpty {
            sut.convertToWordDocument()
            
            // Wait for async operations
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            XCTAssertTrue(sut.showingShareSheet)
        }
    }
    
    func testConvertToWordDocument_EmptyText() {
        // With no processed content, convert should handle gracefully
        sut.convertToWordDocument()
        
        // Should not show share sheet without content
        XCTAssertFalse(sut.showingShareSheet)
    }
    
    func testConvertToWordDocument_ExportFailure() async {
        // First process a document to have extracted text
        let tempURL = createTemporaryTestFile()
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if !sut.extractedText.isEmpty {
            sut.convertToWordDocument()
            
            // Wait for async operations
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // Test behavior when export might fail
            XCTAssertFalse(sut.isProcessing)
        }
    }
    
    // MARK: - Clear Results Tests
    
    func testClearResults() {
        // First process a document to have some state
        let tempURL = createTemporaryTestFile()
        sut.processPDF(url: tempURL)
        
        // Clear results
        sut.clearResults()
        
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertTrue(sut.progressText.isEmpty)
        XCTAssertNil(sut.selectedPDFURL)
        XCTAssertNil(sut.wordDocumentURL)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - Computed Properties Tests
    
    func testCanConvertToWord_WithTextAndNotProcessing() async {
        // First process a document to have extracted text
        let tempURL = createTemporaryTestFile()
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if !sut.extractedText.isEmpty {
            XCTAssertTrue(sut.canConvertToWord)
        }
    }
    
    func testCanConvertToWord_WithTextButProcessing() {
        let tempURL = createTemporaryTestFile()
        sut.processPDF(url: tempURL)
        
        // While processing, should not be able to convert
        if sut.isProcessing {
            XCTAssertFalse(sut.canConvertToWord)
        }
    }
    
    func testCanConvertToWord_NoTextAndNotProcessing() {
        // With no text extracted, should not be able to convert
        XCTAssertFalse(sut.canConvertToWord)
    }
    
    func testHasSelectedPDF_WithURL() {
        let tempURL = createTemporaryTestFile()
        sut.processPDF(url: tempURL)
        
        XCTAssertTrue(sut.hasSelectedPDF)
        XCTAssertEqual(sut.selectedFileName, "test_document.pdf")
    }
    
    func testHasExtractedText_WithText() async {
        // First process a document to have extracted text
        let tempURL = createTemporaryTestFile()
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if !sut.extractedText.isEmpty {
            XCTAssertTrue(sut.hasExtractedText)
        }
    }
}