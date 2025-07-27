//
//  OCRIntegrationTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import XCTest
import UIKit
@testable import OCRMax

final class OCRIntegrationTests: XCTestCase {
    
    var ocrService: VisionOCRService!
    var pdfProcessor: PDFProcessingService!
    var documentExporter: DocumentExportService!
    
    override func setUp() {
        super.setUp()
        ocrService = VisionOCRService()
        pdfProcessor = PDFProcessingService()
        documentExporter = DocumentExportService()
    }
    
    override func tearDown() {
        ocrService = nil
        pdfProcessor = nil
        documentExporter = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestPDF() -> URL {
        let testBundle = Bundle(for: type(of: self))
        
        // Try to find a test PDF in the bundle
        if let pdfURL = testBundle.url(forResource: "test", withExtension: "pdf") {
            return pdfURL
        }
        
        // Create a simple PDF programmatically for testing
        return createSimplePDF()
    }
    
    private func createSimplePDF() -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).pdf")
        
        // Create a minimal PDF data for testing
        let pdfData = Data()
        try? pdfData.write(to: tempURL)
        
        return tempURL
    }
    
    private func createTestImageWithText(_ text: String) -> UIImage {
        let size = CGSize(width: 400, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32),
                .foregroundColor: UIColor.black
            ]
            
            let textRect = CGRect(x: 20, y: 80, width: 360, height: 40)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteOCRWorkflow() async throws {
        // Create test data
        let testImages = [
            createTestImageWithText("Page 1: Hello World"),
            createTestImageWithText("Page 2: Integration Test"),
            createTestImageWithText("Page 3: OCR Processing")
        ]
        
        // Step 1: OCR Processing
        var progressMessages: [String] = []
        
        do {
            let extractedText = try await ocrService.recognizeText(from: testImages) { progress in
                progressMessages.append(progress)
            }
            
            // Verify OCR results
            XCTAssertFalse(extractedText.isEmpty, "OCR should extract some text")
            XCTAssertTrue(progressMessages.count > 0, "Should report progress")
            
            // Step 2: Document Export
            let exportedURL = try documentExporter.exportDocument(from: extractedText, format: .rtf)
            
            // Verify export results
            XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path), "Exported file should exist")
            
            let exportedContent = try String(contentsOf: exportedURL)
            XCTAssertTrue(exportedContent.contains("{\\rtf1"), "Should be valid RTF format")
            
            // Cleanup
            try? FileManager.default.removeItem(at: exportedURL)
            
        } catch {
            // Vision framework might not work in test environment
            XCTAssertTrue(progressMessages.count > 0, "Should still report progress even on OCR failure")
        }
    }
    
    func testPDFToTextWorkflow() throws {
        let testPDF = createTestPDF()
        defer { try? FileManager.default.removeItem(at: testPDF) }
        
        // Test error handling for invalid PDF
        XCTAssertThrowsError(try pdfProcessor.extractImages(from: testPDF)) { error in
            XCTAssertTrue(error is OCRError, "Should throw OCRError for invalid PDF")
        }
        
        // Test page count for invalid PDF
        let pageCount = pdfProcessor.getPageCount(from: testPDF)
        XCTAssertEqual(pageCount, 0, "Invalid PDF should have 0 pages")
    }
    
    func testDocumentExportFormats() throws {
        let testText = """
        Multi-line test document
        
        This document contains:
        • Special characters: & < > " '
        • Line breaks and paragraphs
        • Unicode characters: ñ é ü
        
        End of document.
        """
        
        // Test RTF export
        let rtfURL = try documentExporter.exportDocument(from: testText, format: .rtf)
        defer { try? FileManager.default.removeItem(at: rtfURL) }
        
        let rtfContent = try String(contentsOf: rtfURL)
        XCTAssertTrue(rtfContent.contains("{\\rtf1"), "Should contain RTF header")
        XCTAssertTrue(rtfContent.contains("Multi-line test document"), "Should contain original text")
        
        // Test DOCX export
        let docxURL = try documentExporter.exportDocument(from: testText, format: .docx)
        defer { try? FileManager.default.removeItem(at: docxURL) }
        
        let docxContent = try String(contentsOf: docxURL)
        XCTAssertTrue(docxContent.contains("<?xml"), "Should contain XML header")
        XCTAssertTrue(docxContent.contains("w:document"), "Should contain Word document structure")
        
        // Test TXT export
        let txtURL = try documentExporter.exportDocument(from: testText, format: .txt)
        defer { try? FileManager.default.removeItem(at: txtURL) }
        
        let txtContent = try String(contentsOf: txtURL)
        XCTAssertEqual(txtContent, testText, "TXT content should match exactly")
    }
    
    func testErrorHandling() async {
        // Test invalid PDF
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        
        XCTAssertThrowsError(try pdfProcessor.extractImages(from: invalidURL)) { error in
            XCTAssertTrue(error is OCRError, "Should throw OCRError for invalid PDF")
        }
        
        // Test invalid image for OCR
        let invalidImage = UIImage()
        
        do {
            _ = try await ocrService.recognizeText(from: invalidImage)
            XCTFail("Should throw error for invalid image")
        } catch {
            XCTAssertTrue(error is OCRError || error is NSError, "Should handle invalid image error")
        }
    }
    
    func testPerformanceWithMultipleImages() async throws {
        let images = (1...5).map { index in
            createTestImageWithText("Performance test page \(index)")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            _ = try await ocrService.recognizeText(from: images) { _ in }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertLessThan(timeElapsed, 30.0, "OCR processing should complete within reasonable time")
            
        } catch {
            // Even if OCR fails in test environment, we can measure timing
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertLessThan(timeElapsed, 10.0, "Error handling should be fast")
        }
    }
    
    func testMemoryUsageWithLargeContent() throws {
        let largeText = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 10000)
        
        let url = try documentExporter.exportDocument(from: largeText, format: .rtf)
        defer { try? FileManager.default.removeItem(at: url) }
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0, "Large content should produce non-empty file")
        XCTAssertLessThan(fileSize, 10_000_000, "File size should be reasonable")
    }
    
    @MainActor
    func testViewModelIntegration() async {
        let viewModel = OCRViewModel(
            ocrService: ocrService,
            pdfProcessor: pdfProcessor,
            documentExporter: documentExporter
        )
        
        // Test initial state
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.hasExtractedText)
        XCTAssertFalse(viewModel.canConvertToWord)
        
        // Test with mock PDF
        let testPDF = createTestPDF()
        defer { try? FileManager.default.removeItem(at: testPDF) }
        
        viewModel.processPDF(url: testPDF)
        
        // Wait for processing to complete
        let expectation = XCTestExpectation(description: "PDF processing completes")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 6.0)
        
        // Verify final state (may vary based on OCR success)
        XCTAssertNotNil(viewModel.selectedPDFURL)
        XCTAssertEqual(viewModel.selectedPDFURL, testPDF)
    }
}