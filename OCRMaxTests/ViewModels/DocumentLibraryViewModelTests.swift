//
//  DocumentLibraryViewModelTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import XCTest
import UIKit
@testable import OCRMax

@MainActor
final class DocumentLibraryViewModelTests: XCTestCase {
    
    var sut: DocumentLibraryViewModel!
    var mockDocumentExporter: MockDocumentExporter!
    
    override func setUp() {
        super.setUp()
        mockDocumentExporter = MockDocumentExporter()
        sut = DocumentLibraryViewModel(documentExporter: mockDocumentExporter)
    }
    
    override func tearDown() {
        sut = nil
        mockDocumentExporter = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertTrue(sut.processedDocuments.isEmpty)
        XCTAssertNil(sut.selectedPDFURL)
        XCTAssertNil(sut.wordDocumentURL)
        XCTAssertFalse(sut.showingShareSheet)
        XCTAssertFalse(sut.showingCamera)
        XCTAssertFalse(sut.showingDocumentScanner)
        XCTAssertTrue(sut.capturedImages.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasSelectedPDFWithoutPDF() {
        XCTAssertFalse(sut.hasSelectedPDF)
    }
    
    func testHasSelectedPDFWithPDF() {
        sut.selectedPDFURL = URL(fileURLWithPath: "/test/document.pdf")
        XCTAssertTrue(sut.hasSelectedPDF)
    }
    
    func testSelectedFileNameWithoutPDF() {
        XCTAssertTrue(sut.selectedFileName.isEmpty)
    }
    
    func testSelectedFileNameWithPDF() {
        sut.selectedPDFURL = URL(fileURLWithPath: "/test/document.pdf")
        XCTAssertEqual(sut.selectedFileName, "document.pdf")
    }
    
    func testHasSelectedSourceWithoutSources() {
        XCTAssertFalse(sut.hasSelectedSource)
    }
    
    func testHasSelectedSourceWithPDF() {
        sut.selectedPDFURL = URL(fileURLWithPath: "/test/document.pdf")
        XCTAssertTrue(sut.hasSelectedSource)
    }
    
    func testHasSelectedSourceWithImages() {
        sut.capturedImages = [createTestImage()]
        XCTAssertTrue(sut.hasSelectedSource)
    }
    
    func testHasDocumentsWithoutDocuments() {
        XCTAssertFalse(sut.hasDocuments)
    }
    
    func testHasDocumentsWithDocuments() {
        let document = createMockProcessedDocument()
        sut.processedDocuments = [document]
        XCTAssertTrue(sut.hasDocuments)
    }
    
    func testRecentDocuments() {
        let documents = (1...10).map { index in
            createMockProcessedDocument(name: "Document \(index)")
        }
        sut.processedDocuments = documents
        
        let recentDocs = sut.recentDocuments
        XCTAssertEqual(recentDocs.count, 5)
        XCTAssertEqual(recentDocs.first?.name, "Document 1")
    }
    
    // MARK: - Document Management Tests
    
    func testAddProcessedDocument() {
        let document = createMockProcessedDocument()
        sut.processedDocuments.append(document)
        
        XCTAssertEqual(sut.processedDocuments.count, 1)
        XCTAssertEqual(sut.processedDocuments.first?.name, document.name)
    }
    
    func testRemoveProcessedDocument() {
        let document1 = createMockProcessedDocument(name: "Document 1")
        let document2 = createMockProcessedDocument(name: "Document 2")
        sut.processedDocuments = [document1, document2]
        
        sut.deleteDocument(document1)
        
        XCTAssertEqual(sut.processedDocuments.count, 1)
        XCTAssertEqual(sut.processedDocuments.first?.name, "Document 2")
    }
    
    func testClearAllDocuments() {
        let documents = (1...5).map { index in
            createMockProcessedDocument(name: "Document \(index)")
        }
        sut.processedDocuments = documents
        
        sut.processedDocuments = []
        
        XCTAssertTrue(sut.processedDocuments.isEmpty)
    }
    
    // MARK: - PDF Selection Tests
    
    func testSelectPDF() {
        let testURL = URL(fileURLWithPath: "/test/document.pdf")
        sut.selectPDF(url: testURL)
        
        XCTAssertEqual(sut.selectedPDFURL, testURL)
        XCTAssertTrue(sut.capturedImages.isEmpty) // Should clear images when PDF is selected
    }
    
    func testClearPDFSelection() {
        sut.selectedPDFURL = URL(fileURLWithPath: "/test/document.pdf")
        sut.clearSelection()
        
        XCTAssertNil(sut.selectedPDFURL)
    }
    
    // MARK: - Image Capture Tests
    
    func testAddCapturedImage() {
        let testImage = createTestImage()
        sut.handleCapturedImage(testImage)
        
        XCTAssertEqual(sut.capturedImages.count, 1)
        XCTAssertNil(sut.selectedPDFURL) // Should clear PDF when images are added
    }
    
    func testRemoveCapturedImage() {
        let image1 = createTestImage()
        let image2 = createTestImage()
        sut.capturedImages = [image1, image2]
        
        sut.capturedImages.remove(at: 0)
        
        XCTAssertEqual(sut.capturedImages.count, 1)
    }
    
    func testClearCapturedImages() {
        sut.capturedImages = [createTestImage(), createTestImage()]
        sut.capturedImages = []
        
        XCTAssertTrue(sut.capturedImages.isEmpty)
    }
    
    // MARK: - Export Tests
    
    func testSuccessfulExportToWord() async {
        let testText = "Sample document text"
        mockDocumentExporter.mockURL = URL(fileURLWithPath: "/tmp/exported.rtf")
        
        sut.convertToWordDocument(extractedText: testText)
        
        // Allow some time for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockDocumentExporter.exportDocumentCallCount, 1)
        XCTAssertEqual(mockDocumentExporter.lastExportedText, testText)
        XCTAssertEqual(mockDocumentExporter.lastExportedFormat, .rtf)
        XCTAssertNotNil(sut.wordDocumentURL)
        XCTAssertTrue(sut.showingShareSheet)
        XCTAssertFalse(sut.showingError)
    }
    
    func testFailedExportToWord() async {
        let testText = "Sample document text"
        mockDocumentExporter.shouldSucceed = false
        
        sut.convertToWordDocument(extractedText: testText)
        
        // Allow some time for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockDocumentExporter.exportDocumentCallCount, 1)
        XCTAssertNil(sut.wordDocumentURL)
        XCTAssertFalse(sut.showingShareSheet)
        XCTAssertTrue(sut.showingError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testExportToWordWithEmptyText() async {
        sut.convertToWordDocument(extractedText: "")
        
        XCTAssertEqual(mockDocumentExporter.exportDocumentCallCount, 0)
        XCTAssertTrue(sut.showingError)
        XCTAssertEqual(sut.errorMessage, "No text available to convert")
    }
    
    // MARK: - UI State Tests
    
    func testShowCamera() {
        sut.showCamera()
        XCTAssertTrue(sut.showingCamera)
    }
    
    func testDismissCamera() {
        sut.showingCamera = true
        sut.showingCamera = false
        XCTAssertFalse(sut.showingCamera)
    }
    
    func testShowDocumentScanner() {
        sut.showDocumentScanner()
        XCTAssertTrue(sut.showingDocumentScanner)
    }
    
    func testDismissDocumentScanner() {
        sut.showingDocumentScanner = true
        sut.showingDocumentScanner = false
        XCTAssertFalse(sut.showingDocumentScanner)
    }
    
    func testDismissShareSheet() {
        sut.showingShareSheet = true
        sut.showingShareSheet = false
        XCTAssertFalse(sut.showingShareSheet)
    }
    
    func testDismissError() {
        sut.showingError = true
        sut.errorMessage = "Test error"
        
        sut.showingError = false
        sut.errorMessage = nil
        
        XCTAssertFalse(sut.showingError)
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - Clear All State Tests
    
    func testClearAllState() {
        // Set up some state
        sut.selectedPDFURL = URL(fileURLWithPath: "/test/document.pdf")
        sut.capturedImages = [createTestImage()]
        sut.wordDocumentURL = URL(fileURLWithPath: "/tmp/exported.rtf")
        sut.showingShareSheet = true
        sut.errorMessage = "Test error"
        sut.showingError = true
        
        sut.clearSelection()
        sut.showingShareSheet = false
        sut.errorMessage = nil
        sut.showingError = false
        
        XCTAssertNil(sut.selectedPDFURL)
        XCTAssertTrue(sut.capturedImages.isEmpty)
        XCTAssertNil(sut.wordDocumentURL)
        XCTAssertFalse(sut.showingShareSheet)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createMockProcessedDocument(name: String = "Test Document") -> ProcessedDocument {
        return ProcessedDocument(
            name: name,
            extractedText: "Sample extracted text",
            createdDate: Date(),
            sourceURL: nil,
            wordDocumentURL: nil
        )
    }
} 