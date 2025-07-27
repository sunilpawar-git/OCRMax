//
//  TesseractOCRServiceTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import XCTest
@testable import OCRMax

final class TesseractOCRServiceTests: XCTestCase {
    
    var tesseractService: TesseractOCRService!
    var testImage: UIImage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tesseractService = TesseractOCRService(language: "eng")
        testImage = createTestImage()
    }
    
    override func tearDownWithError() throws {
        tesseractService = nil
        testImage = nil
        try super.tearDownWithError()
    }
    
    func testInitialization() {
        XCTAssertNotNil(tesseractService)
        XCTAssertTrue(tesseractService.isLanguageSupported("eng"))
    }
    
    func testSupportedLanguages() {
        let supportedLanguages = tesseractService.getSupportedLanguages()
        
        XCTAssertTrue(supportedLanguages.contains("eng"))
        XCTAssertTrue(supportedLanguages.contains("fra"))
        XCTAssertTrue(supportedLanguages.contains("deu"))
        XCTAssertTrue(supportedLanguages.contains("spa"))
    }
    
    func testLanguageSupport() {
        XCTAssertTrue(tesseractService.isLanguageSupported("eng"))
        XCTAssertTrue(tesseractService.isLanguageSupported("fra"))
        XCTAssertTrue(tesseractService.isLanguageSupported("spa"))
    }
    
    func testRecognizeTextFromSingleImage() async throws {
        let expectation = expectation(description: "Text recognition should complete")
        
        Task {
            do {
                let recognizedText = try await tesseractService.recognizeText(from: testImage)
                XCTAssertNotNil(recognizedText)
                XCTAssertFalse(recognizedText.isEmpty)
                expectation.fulfill()
            } catch {
                if case OCRError.noTextFound = error {
                    expectation.fulfill()
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    func testRecognizeTextFromMultipleImages() async throws {
        let images = [testImage!, testImage!]
        let expectation = expectation(description: "Multiple image processing should complete")
        var progressUpdates: [String] = []
        
        Task {
            do {
                let recognizedText = try await tesseractService.recognizeText(from: images) { progress in
                    progressUpdates.append(progress)
                }
                
                XCTAssertNotNil(recognizedText)
                XCTAssertFalse(progressUpdates.isEmpty)
                expectation.fulfill()
            } catch {
                if case OCRError.noTextFound = error {
                    expectation.fulfill()
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 60.0)
    }
    
    func testLanguageSetting() {
        tesseractService.setLanguage("fra")
        tesseractService.setLanguage("deu")
        tesseractService.setLanguage("spa")
    }
    
    func testPageSegmentationMode() {
        tesseractService.setPageSegmentationMode(6)
        tesseractService.setPageSegmentationMode(4)
        tesseractService.setPageSegmentationMode(1)
    }
    
    func testEngineMode() {
        tesseractService.setEngineMode(3)
        tesseractService.setEngineMode(0)
        tesseractService.setEngineMode(1)
    }
    
    func testCharacterWhitelistAndBlacklist() {
        tesseractService.setCharacterWhitelist("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        tesseractService.setCharacterBlacklist("!@#$%^&*()")
        
        tesseractService.setCharacterWhitelist(nil)
        tesseractService.setCharacterBlacklist(nil)
    }
    
    func testInvalidImageHandling() async {
        let invalidImage = UIImage()
        
        do {
            _ = try await tesseractService.recognizeText(from: invalidImage)
        } catch {
            if case OCRError.noTextFound = error {
                XCTAssertTrue(true, "Expected no text found error for invalid image")
            } else {
                XCTFail("Expected OCRError.noTextFound, got \(error)")
            }
        }
    }
    
    func testEmptyImageArrayHandling() async {
        let emptyImages: [UIImage] = []
        
        do {
            _ = try await tesseractService.recognizeText(from: emptyImages) { _ in }
            XCTFail("Should throw error for empty image array")
        } catch {
            if case OCRError.noTextFound = error {
                XCTAssertTrue(true, "Expected no text found error for empty image array")
            } else {
                XCTFail("Expected OCRError.noTextFound, got \(error)")
            }
        }
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 300, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        let text = "Test Text 123"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
}