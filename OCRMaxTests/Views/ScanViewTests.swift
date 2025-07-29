//
//  ScanViewTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 29/07/25.
//

import XCTest
import SwiftUI
@testable import OCRMax

// Type alias for MockPDFProcessingService (referencing MockPDFProcessor)
typealias MockPDFProcessingService = MockPDFProcessor

@MainActor
final class ScanViewTests: XCTestCase {
    
    var sut: ScanView!
    var mockViewModel: OCRViewModel!
    
    override func setUp() {
        super.setUp()
        mockViewModel = OCRViewModel()
        sut = ScanView(viewModel: mockViewModel)
    }
    
    override func tearDown() {
        sut = nil
        mockViewModel = nil
        super.tearDown()
    }
    
    // MARK: - View Initialization Tests
    
    func testScanViewInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(mockViewModel)
    }
    
    func testBodyRendersCorrectly() {
        // Test that the main body renders without crashing
        let body = sut.body
        XCTAssertNotNil(body)
    }
    
    // MARK: - Processing State Tests
    
    func testProcessingStateDisplay() {
        // Test processing state by manipulating the underlying view model
        mockViewModel.ocrProcessingViewModel.isProcessing = true
        mockViewModel.ocrProcessingViewModel.progressText = "Processing..."
        
        let body = sut.body
        XCTAssertNotNil(body)
        XCTAssertTrue(mockViewModel.isProcessing)
        XCTAssertEqual(mockViewModel.progressText, "Processing...")
    }
    
    func testIdleStateDisplay() {
        // Test idle state
        mockViewModel.ocrProcessingViewModel.isProcessing = false
        mockViewModel.ocrProcessingViewModel.progressText = ""
        
        let body = sut.body
        XCTAssertNotNil(body)
        XCTAssertFalse(mockViewModel.isProcessing)
    }
    
    func testResultStateDisplay() {
        // Test result state
        mockViewModel.ocrProcessingViewModel.isProcessing = false
        mockViewModel.ocrProcessingViewModel.extractedText = "Sample extracted text"
        mockViewModel.documentLibraryViewModel.wordDocumentURL = URL(fileURLWithPath: "/tmp/result.rtf")
        
        let body = sut.body
        XCTAssertNotNil(body)
        XCTAssertFalse(mockViewModel.isProcessing)
        XCTAssertFalse(mockViewModel.extractedText.isEmpty)
    }
    
    // MARK: - File Selection Tests
    
    func testFileURLProperties() {
        let testURL = URL(fileURLWithPath: "/test/sample.pdf")
        
        mockViewModel.documentLibraryViewModel.selectedPDFURL = testURL
        
        XCTAssertEqual(mockViewModel.selectedPDFURL, testURL)
        XCTAssertEqual(mockViewModel.selectedFileName, "sample.pdf")
    }
    
    func testImageSelection() {
        let testImages = [createTestImage(), createTestImage()]
        mockViewModel.documentLibraryViewModel.capturedImages = testImages
        
        XCTAssertEqual(mockViewModel.capturedImages.count, 2)
    }
    
    // MARK: - Processing Progress Tests
    
    func testProcessingProgress() {
        mockViewModel.ocrProcessingViewModel.isProcessing = true
        mockViewModel.ocrProcessingViewModel.progressText = "Processing page 8 of 12"
        
        XCTAssertTrue(mockViewModel.isProcessing)
        XCTAssertEqual(mockViewModel.progressText, "Processing page 8 of 12")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorState() {
        mockViewModel.ocrProcessingViewModel.showingError = true
        mockViewModel.ocrProcessingViewModel.errorMessage = "Processing failed"
        
        XCTAssertTrue(mockViewModel.showingError)
        XCTAssertEqual(mockViewModel.errorMessage, "Processing failed")
    }
    
    // MARK: - Share Sheet Tests
    
    func testShareSheetPresentation() {
        mockViewModel.documentLibraryViewModel.wordDocumentURL = URL(fileURLWithPath: "/tmp/document.rtf")
        mockViewModel.documentLibraryViewModel.showingShareSheet = true
        
        XCTAssertNotNil(mockViewModel.wordDocumentURL)
        XCTAssertTrue(mockViewModel.showingShareSheet)
    }
    
    // MARK: - View Model State Tests
    
    func testViewModelStateTransitions() {
        // Test idle to processing transition
        XCTAssertFalse(mockViewModel.isProcessing)
        
        mockViewModel.ocrProcessingViewModel.isProcessing = true
        XCTAssertTrue(mockViewModel.isProcessing)
        
        // Test processing to completed transition
        mockViewModel.ocrProcessingViewModel.isProcessing = false
        mockViewModel.ocrProcessingViewModel.extractedText = "Completed text"
        
        XCTAssertFalse(mockViewModel.isProcessing)
        XCTAssertFalse(mockViewModel.extractedText.isEmpty)
    }
    
    // MARK: - Camera and Scanner Tests
    
    func testCameraProperties() {
        mockViewModel.documentLibraryViewModel.showingCamera = true
        XCTAssertTrue(mockViewModel.showingCamera)
        
        mockViewModel.documentLibraryViewModel.showingCamera = false
        XCTAssertFalse(mockViewModel.showingCamera)
    }
    
    func testDocumentScannerProperties() {
        mockViewModel.documentLibraryViewModel.showingDocumentScanner = true
        XCTAssertTrue(mockViewModel.showingDocumentScanner)
        
        mockViewModel.documentLibraryViewModel.showingDocumentScanner = false
        XCTAssertFalse(mockViewModel.showingDocumentScanner)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}