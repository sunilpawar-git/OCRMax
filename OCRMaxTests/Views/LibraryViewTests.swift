//
//  LibraryViewTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 29/07/25.
//

import XCTest
import SwiftUI
@testable import OCRMax

@MainActor
final class LibraryViewTests: XCTestCase {
    
    var sut: LibraryView!
    var mockOCRViewModel: OCRViewModel!
    
    override func setUp() {
        super.setUp()
        // Create an OCRViewModel with default dependencies 
        // We'll control its state through its child view models
        mockOCRViewModel = OCRViewModel()
        sut = LibraryView(viewModel: mockOCRViewModel)
    }
    
    override func tearDown() {
        sut = nil
        mockOCRViewModel = nil
        super.tearDown()
    }
    
    // MARK: - View Initialization Tests
    
    func testLibraryViewInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(mockOCRViewModel)
    }
    
    func testEmptyStateViewRenders() {
        // Clear any existing documents to ensure empty state
        mockOCRViewModel.documentLibraryViewModel.processedDocuments.removeAll()
        
        // Access the body property to trigger rendering
        let body = sut.body
        XCTAssertNotNil(body)
        
        // Verify empty state
        XCTAssertTrue(mockOCRViewModel.processedDocuments.isEmpty)
    }
    
    func testDocumentListViewRenders() {
        // Add test documents
        let testDocument1 = createMockProcessedDocument(name: "Test Document 1")
        let testDocument2 = createMockProcessedDocument(name: "Test Document 2")
        
        mockOCRViewModel.documentLibraryViewModel.processedDocuments = [testDocument1, testDocument2]
        
        // Access the body property to trigger rendering
        let body = sut.body
        XCTAssertNotNil(body)
        
        // Verify documents are present
        XCTAssertEqual(mockOCRViewModel.processedDocuments.count, 2)
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationTitle() {
        let body = sut.body
        XCTAssertNotNil(body)
        // The navigation title is set within the view
    }
    
    // MARK: - Document Management Tests
    
    func testLoadProcessedDocuments() {
        // Call loadProcessedDocuments and verify it doesn't crash
        mockOCRViewModel.loadProcessedDocuments()
        
        // The method should complete without throwing
        XCTAssertNotNil(mockOCRViewModel)
    }
    
    func testDeleteDocument() {
        let document = createMockProcessedDocument()
        mockOCRViewModel.documentLibraryViewModel.processedDocuments = [document]
        
        XCTAssertEqual(mockOCRViewModel.processedDocuments.count, 1)
        
        mockOCRViewModel.deleteDocument(document)
        
        XCTAssertEqual(mockOCRViewModel.processedDocuments.count, 0)
    }
    
    func testDeleteDocumentsAtOffsets() {
        let doc1 = createMockProcessedDocument(name: "Doc 1")
        let doc2 = createMockProcessedDocument(name: "Doc 2")
        mockOCRViewModel.documentLibraryViewModel.processedDocuments = [doc1, doc2]
        
        XCTAssertEqual(mockOCRViewModel.processedDocuments.count, 2)
        
        let indexSet = IndexSet([0])
        mockOCRViewModel.deleteDocuments(at: indexSet)
        
        XCTAssertEqual(mockOCRViewModel.processedDocuments.count, 1)
        XCTAssertEqual(mockOCRViewModel.processedDocuments.first?.name, "Doc 2")
    }
    
    // MARK: - State Management Tests
    
    func testEmptyToPopulatedStateTransition() {
        // Start with empty state
        mockOCRViewModel.documentLibraryViewModel.processedDocuments.removeAll()
        XCTAssertTrue(mockOCRViewModel.processedDocuments.isEmpty)
        
        // Add documents
        let document = createMockProcessedDocument()
        mockOCRViewModel.documentLibraryViewModel.processedDocuments.append(document)
        
        XCTAssertFalse(mockOCRViewModel.processedDocuments.isEmpty)
        XCTAssertEqual(mockOCRViewModel.processedDocuments.count, 1)
    }
    
    func testPopulatedToEmptyStateTransition() {
        // Start with documents
        let document = createMockProcessedDocument()
        mockOCRViewModel.documentLibraryViewModel.processedDocuments = [document]
        XCTAssertFalse(mockOCRViewModel.processedDocuments.isEmpty)
        
        // Clear documents
        mockOCRViewModel.documentLibraryViewModel.processedDocuments.removeAll()
        
        XCTAssertTrue(mockOCRViewModel.processedDocuments.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func createMockProcessedDocument(name: String = "Test Document") -> ProcessedDocument {
        return ProcessedDocument(
            name: name,
            extractedText: "Sample extracted text from \(name)",
            createdDate: Date(),
            sourceURL: URL(fileURLWithPath: "/test/\(name).pdf"),
            wordDocumentURL: URL(fileURLWithPath: "/tmp/\(name).rtf")
        )
    }
}