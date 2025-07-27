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
    var mockOCRService: MockOCRService!
    var mockPDFProcessor: MockPDFProcessor!
    var mockDocumentExporter: MockDocumentExporter!
    
    override func setUp() {
        super.setUp()
        mockOCRService = MockOCRService()
        mockPDFProcessor = MockPDFProcessor()
        mockDocumentExporter = MockDocumentExporter()
        
        sut = OCRViewModel(
            ocrService: mockOCRService,
            pdfProcessor: mockPDFProcessor,
            documentExporter: mockDocumentExporter
        )
    }
    
    override func tearDown() {
        sut = nil
        mockOCRService = nil
        mockPDFProcessor = nil
        mockDocumentExporter = nil
        super.tearDown()
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
        XCTAssertTrue(sut.pdfFileName.isEmpty)
    }
    
    // MARK: - PDF Processing Tests
    
    func testProcessPDF_Success() async {
        let testURL = URL(fileURLWithPath: "/test/document.pdf")
        mockOCRService.mockText = "Extracted PDF content"
        
        sut.processPDF(url: testURL)
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(sut.selectedPDFURL, testURL)
        XCTAssertEqual(sut.extractedText, "Extracted PDF content")
        XCTAssertEqual(mockPDFProcessor.extractImagesCallCount, 1)
        XCTAssertEqual(mockOCRService.recognizeTextFromImagesCallCount, 1)
        XCTAssertTrue(sut.hasSelectedPDF)
        XCTAssertTrue(sut.hasExtractedText)
        XCTAssertEqual(sut.pdfFileName, "document.pdf")
    }
    
    func testProcessPDF_PDFProcessorFailure() async {
        let testURL = URL(fileURLWithPath: "/test/document.pdf")
        mockPDFProcessor.shouldSucceed = false
        mockPDFProcessor.mockError = OCRError.fileAccessDenied
        
        sut.processPDF(url: testURL)
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(sut.selectedPDFURL, testURL)
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.showingError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testProcessPDF_OCRServiceFailure() async {
        let testURL = URL(fileURLWithPath: "/test/document.pdf")
        mockOCRService.shouldSucceed = false
        mockOCRService.mockError = OCRError.noTextFound
        
        sut.processPDF(url: testURL)
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(sut.selectedPDFURL, testURL)
        XCTAssertTrue(sut.extractedText.isEmpty)
        XCTAssertFalse(sut.isProcessing)
        XCTAssertTrue(sut.showingError)
        XCTAssertEqual(sut.errorMessage, OCRError.noTextFound.localizedDescription)
    }
    
    func testProcessPDF_IgnoresSubsequentCallsWhileProcessing() {
        let testURL1 = URL(fileURLWithPath: "/test/document1.pdf")
        let testURL2 = URL(fileURLWithPath: "/test/document2.pdf")
        
        sut.processPDF(url: testURL1)
        XCTAssertTrue(sut.isProcessing)
        
        sut.processPDF(url: testURL2)
        
        XCTAssertEqual(sut.selectedPDFURL, testURL1)
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
        XCTAssertEqual(sut.pdfFileName, "test.pdf")
    }
    
    func testHasExtractedText_WithText() {
        sut.extractedText = "Some extracted text"
        
        XCTAssertTrue(sut.hasExtractedText)
    }
}