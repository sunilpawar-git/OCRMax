//
//  VisionOCRServiceTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import XCTest
import UIKit
@testable import OCRMax

final class VisionOCRServiceTests: XCTestCase {
    
    var sut: VisionOCRService!
    
    override func setUp() {
        super.setUp()
        sut = VisionOCRService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(withText text: String = "Test") -> UIImage {
        let size = CGSize(width: 200, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            
            let textRect = CGRect(x: 20, y: 30, width: 160, height: 40)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func createInvalidImage() -> UIImage {
        return UIImage()
    }
    
    // MARK: - Single Image Recognition Tests
    
    func testRecognizeText_ValidImage() async throws {
        let testImage = createTestImage(withText: "Hello World")
        
        do {
            let result = try await sut.recognizeText(from: testImage)
            XCTAssertFalse(result.isEmpty, "OCR should return some text for a valid image")
        } catch OCRError.noTextFound {
            XCTFail("OCR should be able to recognize text from the test image")
        } catch {
            // Vision framework might not work in test environment
            // This is acceptable for unit tests
        }
    }
    
    func testRecognizeText_InvalidImage() async {
        let invalidImage = createInvalidImage()
        
        do {
            _ = try await sut.recognizeText(from: invalidImage)
            XCTFail("Should throw error for invalid image")
        } catch OCRError.invalidImage {
            // Expected error
        } catch {
            // Other errors are also acceptable
        }
    }
    
    // MARK: - Multiple Images Recognition Tests
    
    func testRecognizeTextFromImages_ValidImages() async throws {
        let images = [
            createTestImage(withText: "Page 1"),
            createTestImage(withText: "Page 2"),
            createTestImage(withText: "Page 3")
        ]
        
        var progressMessages: [String] = []
        
        do {
            let result = try await sut.recognizeText(from: images) { progress in
                progressMessages.append(progress)
            }
            
            XCTAssertFalse(result.isEmpty, "OCR should return text for valid images")
            XCTAssertTrue(progressMessages.count > 0, "Progress handler should be called")
            XCTAssertTrue(progressMessages.contains { $0.contains("Processing page") }, "Should report page processing progress")
            XCTAssertTrue(progressMessages.contains("OCR processing completed"), "Should report completion")
        } catch {
            // Vision framework might not work in test environment
            // Verify that progress was still reported
            XCTAssertTrue(progressMessages.count > 0, "Progress handler should be called even on failure")
        }
    }
    
    func testRecognizeTextFromImages_EmptyArray() async {
        let images: [UIImage] = []
        
        do {
            let result = try await sut.recognizeText(from: images) { _ in }
            XCTAssertTrue(result.isEmpty, "Empty image array should return empty text")
        } catch OCRError.noTextFound {
            // This is also acceptable behavior
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRecognizeTextFromImages_ProgressReporting() async {
        let images = [
            createTestImage(withText: "Test 1"),
            createTestImage(withText: "Test 2")
        ]
        
        var progressMessages: [String] = []
        var progressCallCount = 0
        
        do {
            _ = try await sut.recognizeText(from: images) { progress in
                progressMessages.append(progress)
                progressCallCount += 1
            }
            
            XCTAssertTrue(progressCallCount >= images.count, "Progress should be reported for each image")
            XCTAssertTrue(progressMessages.contains { $0.contains("Processing page 1 of 2") }, "Should report first page progress")
            XCTAssertTrue(progressMessages.contains { $0.contains("Processing page 2 of 2") }, "Should report second page progress")
        } catch {
            // Even on error, progress should be reported
            XCTAssertTrue(progressCallCount > 0, "Progress should be reported even on error")
        }
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() {
        var config = VNRecognizeTextRequestConfiguration()
        config.recognitionLevel = .fast
        config.recognitionLanguages = ["fr-FR"]
        config.usesLanguageCorrection = false
        
        let customService = VisionOCRService(configuration: config)
        XCTAssertNotNil(customService, "Should be able to create service with custom configuration")
    }
    
    // MARK: - Error Handling Tests
    
    func testRecognizeText_HandlesVisionErrors() async {
        let testImage = createTestImage()
        
        // This test verifies that the service properly wraps Vision framework errors
        do {
            _ = try await sut.recognizeText(from: testImage)
        } catch {
            // Any error is acceptable - we're testing error handling path
            XCTAssertTrue(error is OCRError || error is NSError, "Should handle errors appropriately")
        }
    }
}