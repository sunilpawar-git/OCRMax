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
        
        sut = OCRViewModel(
            visionOCRService: mockVisionOCRService,
            tesseractOCRService: mockTesseractOCRService,
            pdfProcessor: mockPDFProcessor,
            documentExporter: mockDocumentExporter
        )
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
        mockVisionOCRService.mockText = "Extracted PDF content"
        
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete by monitoring isProcessing flag
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 15 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Wait a bit more for final UI updates (ViewModel has a 2 second delay)
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds to be safe
        
        // Debug output
        print("Debug - selectedPDFURL: \(String(describing: sut.selectedPDFURL))")
        print("Debug - extractedText: '\(sut.extractedText)'")
        print("Debug - isProcessing: \(sut.isProcessing)")
        print("Debug - showingError: \(sut.showingError)")
        print("Debug - errorMessage: \(String(describing: sut.errorMessage))")
        print("Debug - extractImagesCallCount: \(mockPDFProcessor.extractImagesCallCount)")
        print("Debug - recognizeTextFromImagesCallCount: \(mockVisionOCRService.recognizeTextFromImagesCallCount)")
        
        XCTAssertEqual(sut.selectedPDFURL, tempURL)
        XCTAssertEqual(sut.extractedText, "Extracted PDF content")
        XCTAssertEqual(mockPDFProcessor.extractImagesCallCount, 1)
        XCTAssertEqual(mockVisionOCRService.recognizeTextFromImagesCallCount, 1)
        XCTAssertTrue(sut.hasSelectedPDF)
        XCTAssertTrue(sut.hasExtractedText)
        XCTAssertEqual(sut.selectedFileName, "test_document.pdf")
        XCTAssertFalse(sut.isProcessing)
    }
    
    func testProcessPDF_PDFProcessorFailure() async {
        let tempURL = createTemporaryTestFile()
        mockPDFProcessor.shouldSucceed = false
        mockPDFProcessor.mockError = OCRError.fileAccessDenied
        
        sut.processPDF(url: tempURL)
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(sut.selectedPDFURL, tempURL)
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.showingError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testProcessPDF_OCRServiceFailure() async {
        let tempURL = createTemporaryTestFile()
        mockVisionOCRService.shouldSucceed = false
        mockVisionOCRService.mockError = OCRError.noTextFound
        
        sut.processPDF(url: tempURL)
        
        // Wait for processing to complete by monitoring isProcessing flag
        let startTime = Date()
        while sut.isProcessing && Date().timeIntervalSince(startTime) < 5 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Wait a bit more for final UI updates
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        XCTAssertEqual(sut.selectedPDFURL, tempURL)
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.showingError)
        XCTAssertEqual(sut.errorMessage, OCRError.noTextFound.localizedDescription)
    }
    
    func testProcessPDF_IgnoresSubsequentCallsWhileProcessing() async {
        let tempURL1 = createTemporaryTestFile()
        let tempURL2 = createTemporaryTestFile()
        
        // Configure mocks to have a slower processing time so we can test the guard
        mockVisionOCRService.mockText = "First document text"
        
        sut.processPDF(url: tempURL1)
        
        // Give a moment for the first call to start processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        XCTAssertTrue(sut.isProcessing)
        
        sut.processPDF(url: tempURL2)
        
        // Small wait to ensure second call is processed (should be ignored)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // The selected URL should still be the first one
        XCTAssertEqual(sut.selectedPDFURL, tempURL1)
        // Only one call to extract images should have been made
        XCTAssertEqual(mockPDFProcessor.extractImagesCallCount, 1)
    }
    
    // MARK: - Word Document Conversion Tests
    
    func testConvertToWordDocument_Success() async {
        sut.extractedText = "Sample text content"
        mockDocumentExporter.mockURL = URL(fileURLWithPath: "/tmp/output.rtf")
        
        sut.convertToWordDocument()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockDocumentExporter.exportDocumentCallCount, 1)
        XCTAssertEqual(mockDocumentExporter.lastExportedText, "Sample text content")
        XCTAssertEqual(mockDocumentExporter.lastExportedFormat, .rtf)
        XCTAssertNotNil(sut.wordDocumentURL)
        XCTAssertTrue(sut.showingShareSheet)
    }
    
    func testConvertToWordDocument_EmptyText() {
        sut.extractedText = ""
        
        sut.convertToWordDocument()
        
        XCTAssertEqual(mockDocumentExporter.exportDocumentCallCount, 0)
        XCTAssertTrue(sut.showingError)
        XCTAssertEqual(sut.errorMessage, "No text available to convert")
    }
    
    func testConvertToWordDocument_ExportFailure() async {
        sut.extractedText = "Sample text content"
        mockDocumentExporter.shouldSucceed = false
        
        sut.convertToWordDocument()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockDocumentExporter.exportDocumentCallCount, 1)
        XCTAssertNil(sut.wordDocumentURL)
        XCTAssertFalse(sut.showingShareSheet)
        XCTAssertTrue(sut.showingError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    // MARK: - Clear Results Tests
    
    func testClearResults() {
        sut.extractedText = "Some text"
        sut.progressText = "Processing..."
        sut.selectedPDFURL = URL(fileURLWithPath: "/test.pdf")
        sut.wordDocumentURL = URL(fileURLWithPath: "/output.rtf")
        sut.errorMessage = "Some error"
        sut.showingError = true
        
        sut.clearResults()
        
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertTrue(sut.progressText.isEmpty)
        XCTAssertNil(sut.selectedPDFURL)
        XCTAssertNil(sut.wordDocumentURL)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - Computed Properties Tests
    
    func testCanConvertToWord_WithTextAndNotProcessing() {
        sut.extractedText = "Some text"
        sut.isProcessing = false
        
        XCTAssertTrue(sut.canConvertToWord)
    }
    
    func testCanConvertToWord_WithTextButProcessing() {
        sut.extractedText = "Some text"
        sut.isProcessing = true
        
        XCTAssertFalse(sut.canConvertToWord)
    }
    
    func testCanConvertToWord_NoTextAndNotProcessing() {
        sut.extractedText = ""
        sut.isProcessing = false
        
        XCTAssertFalse(sut.canConvertToWord)
    }
    
    func testHasSelectedPDF_WithURL() {
        sut.selectedPDFURL = URL(fileURLWithPath: "/test.pdf")
        
        XCTAssertTrue(sut.hasSelectedPDF)
        XCTAssertEqual(sut.selectedFileName, "test.pdf")
    }
    
    func testHasExtractedText_WithText() {
        sut.extractedText = "Some extracted text"
        
        XCTAssertTrue(sut.hasExtractedText)
    }
}