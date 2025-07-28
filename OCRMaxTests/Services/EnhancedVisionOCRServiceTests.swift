//
//  EnhancedVisionOCRServiceTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import XCTest
import Vision
@testable import OCRMax

final class EnhancedVisionOCRServiceTests: XCTestCase {
    
    var ocrService: EnhancedVisionOCRService!
    
    override func setUp() {
        super.setUp()
        ocrService = EnhancedVisionOCRService()
    }
    
    override func tearDown() {
        ocrService = nil
        super.tearDown()
    }
    
    // MARK: - TextBlock Extraction Tests
    
    func testRecognizeTextBlocksFromImage() async throws {
        let testImage = createTestImage(with: "Test Text")
        
        let textBlocks = try await ocrService.recognizeTextBlocks(from: testImage)
        
        XCTAssertGreaterThan(textBlocks.count, 0)
        XCTAssertTrue(textBlocks.first?.text.contains("Test") ?? false)
        XCTAssertGreaterThan(textBlocks.first?.confidence ?? 0, 0.5)
        XCTAssertNotEqual(textBlocks.first?.boundingBox, .zero)
    }
    
    func testBatchRecognizeTextBlocks() async throws {
        let images = [
            createTestImage(with: "Page 1"),
            createTestImage(with: "Page 2"),
            createTestImage(with: "Page 3")
        ]
        
        var progressUpdates: [String] = []
        let textBlocks = try await ocrService.recognizeTextBlocks(
            from: images,
            progressHandler: { message in
                progressUpdates.append(message)
            }
        )
        
        XCTAssertGreaterThan(textBlocks.count, 0)
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertTrue(progressUpdates.contains { $0.contains("Processing page") })
        
        let pageBlocks = textBlocks.filter { $0.pageIndex == 1 }
        XCTAssertGreaterThan(pageBlocks.count, 0)
    }
    
    func testInvalidImageHandling() async {
        let invalidImage = UIImage()
        
        do {
            _ = try await ocrService.recognizeTextBlocks(from: invalidImage)
            XCTFail("Should have thrown an error for invalid image")
        } catch OCRError.invalidImage {
            // Expected behavior
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testEmptyImageHandling() async throws {
        let emptyImage = createEmptyImage()
        
        do {
            _ = try await ocrService.recognizeTextBlocks(from: emptyImage)
            XCTFail("Should have thrown an error for empty image")
        } catch OCRError.noTextFound {
            // Expected behavior
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibilityRecognizeText() async throws {
        let testImage = createTestImage(with: "Compatibility Test")
        
        let text = try await ocrService.recognizeText(from: testImage)
        
        XCTAssertTrue(text.contains("Compatibility"))
        XCTAssertFalse(text.isEmpty)
    }
    
    func testBatchBackwardCompatibility() async throws {
        let images = [
            createTestImage(with: "Batch 1"),
            createTestImage(with: "Batch 2")
        ]
        
        var progressCalled = false
        let text = try await ocrService.recognizeText(
            from: images,
            progressHandler: { _ in
                progressCalled = true
            }
        )
        
        XCTAssertTrue(progressCalled)
        XCTAssertTrue(text.contains("Batch"))
        XCTAssertTrue(text.contains("Page 1"))
        XCTAssertTrue(text.contains("Page 2"))
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() {
        var config = VNRecognizeTextRequestConfiguration()
        config.recognitionLevel = .fast
        config.recognitionLanguages = ["fr-FR"]
        config.usesLanguageCorrection = false
        
        let customService = EnhancedVisionOCRService(configuration: config)
        
        XCTAssertNotNil(customService)
    }
    
    func testLanguageSettings() {
        ocrService.setLanguage("es-ES")
        let languages = ocrService.getSupportedLanguages()
        
        XCTAssertGreaterThan(languages.count, 0)
        XCTAssertTrue(languages.contains("English"))
    }
    
    // MARK: - Error Handling Tests
    
    func testMultipleImageErrorHandling() async {
        let images = [
            createTestImage(with: "Valid"),
            UIImage(), // Invalid
            createTestImage(with: "Also Valid")
        ]
        
        do {
            let textBlocks = try await ocrService.recognizeTextBlocks(
                from: images,
                progressHandler: { _ in }
            )
            
            // Should continue processing valid images
            XCTAssertGreaterThan(textBlocks.count, 0)
            let pageIndices = Set(textBlocks.map { $0.pageIndex })
            XCTAssertTrue(pageIndices.contains(0)) // First image
            XCTAssertTrue(pageIndices.contains(2)) // Third image
            XCTAssertFalse(pageIndices.contains(1)) // Second (invalid) image
        } catch {
            XCTFail("Should not throw when some images are valid")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBoundingBoxAccuracy() async throws {
        let testImage = createTestImageWithMultipleLines()
        
        let textBlocks = try await ocrService.recognizeTextBlocks(from: testImage)
        
        XCTAssertGreaterThan(textBlocks.count, 1)
        
        // Check that bounding boxes are properly ordered
        let sortedBlocks = TextBlock.sortedByPosition(textBlocks)
        for i in 0..<sortedBlocks.count - 1 {
            let current = sortedBlocks[i]
            let next = sortedBlocks[i + 1]
            
            // Either in same row (similar Y) or next is below current
            XCTAssertTrue(
                abs(current.centerY - next.centerY) < 20 || current.centerY < next.centerY,
                "Text blocks should be properly ordered by position"
            )
        }
    }
    
    // MARK: - Integration Tests
    
    func testIntegrationWithLayoutAnalyzer() async throws {
        let testImage = createComplexLayoutImage()
        let layoutAnalyzer = LayoutAnalyzer()
        
        let textBlocks = try await ocrService.recognizeTextBlocks(from: testImage)
        let analysis = layoutAnalyzer.analyzeLayout(from: textBlocks)
        
        XCTAssertGreaterThan(analysis.textGroups.count, 0)
        XCTAssertGreaterThan(analysis.spacing.averageLineSpacing, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(with text: String) -> UIImage {
        let size = CGSize(width: 300, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: 20, y: 40, width: 260, height: 20)
        attributedString.draw(in: textRect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createEmptyImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createTestImageWithMultipleLines() -> UIImage {
        let size = CGSize(width: 400, height: 200)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let lines = ["First line of text", "Second line below", "Third line continues"]
        for (index, line) in lines.enumerated() {
            let y = CGFloat(20 + index * 30)
            let rect = CGRect(x: 20, y: y, width: 360, height: 20)
            NSAttributedString(string: line, attributes: attributes).draw(in: rect)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createComplexLayoutImage() -> UIImage {
        let size = CGSize(width: 500, height: 400)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        // Title
        NSAttributedString(string: "DOCUMENT TITLE", attributes: titleAttributes)
            .draw(in: CGRect(x: 150, y: 20, width: 200, height: 25))
        
        // Body paragraphs
        let bodyText = ["First paragraph of document", "Second paragraph continues", "Third paragraph ends"]
        for (index, text) in bodyText.enumerated() {
            let y = CGFloat(70 + index * 25)
            NSAttributedString(string: text, attributes: bodyAttributes)
                .draw(in: CGRect(x: 30, y: y, width: 440, height: 20))
        }
        
        // Two columns
        NSAttributedString(string: "Left column text", attributes: bodyAttributes)
            .draw(in: CGRect(x: 30, y: 200, width: 200, height: 20))
        NSAttributedString(string: "Right column text", attributes: bodyAttributes)
            .draw(in: CGRect(x: 270, y: 200, width: 200, height: 20))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}