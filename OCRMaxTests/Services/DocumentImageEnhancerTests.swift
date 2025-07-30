//
//  DocumentImageEnhancerTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 02/01/25.
//

import XCTest
@testable import OCRMax
import UIKit

final class DocumentImageEnhancerTests: XCTestCase {
    
    var enhancer: DocumentImageEnhancer!
    var testImage: UIImage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        enhancer = DocumentImageEnhancer()
        
        // Create a simple test image
        testImage = createTestImage()
    }
    
    override func tearDownWithError() throws {
        enhancer = nil
        testImage = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Test Methods
    
    func testEnhanceImage_ValidImage_ReturnsEnhancedImage() async throws {
        // Given
        let originalImage = testImage!
        
        // When
        let enhancedImage = try await enhancer.enhanceImage(originalImage)
        
        // Then
        XCTAssertNotNil(enhancedImage)
        XCTAssertGreaterThan(enhancedImage.size.width, 0)
        XCTAssertGreaterThan(enhancedImage.size.height, 0)
    }
    
    func testEnhanceImage_InvalidImage_ThrowsError() async {
        // Given
        let invalidImage = UIImage()
        
        // When & Then
        do {
            _ = try await enhancer.enhanceImage(invalidImage)
            XCTFail("Should have thrown an error for invalid image")
        } catch DocumentImageEnhancer.EnhancementError.invalidImage {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testEnhanceImages_MultipleValidImages_ReturnsEnhancedImages() async throws {
        // Given
        let images = [testImage!, testImage!, testImage!]
        var progressMessages: [String] = []
        
        // When
        let enhancedImages = try await enhancer.enhanceImages(images) { message in
            progressMessages.append(message)
        }
        
        // Then
        XCTAssertEqual(enhancedImages.count, 3)
        XCTAssertTrue(progressMessages.contains { $0.contains("Enhancing image") })
        XCTAssertTrue(progressMessages.contains("Image enhancement completed"))
        
        for image in enhancedImages {
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }
    
    func testEnhanceImages_MixedValidInvalidImages_HandlesGracefully() async throws {
        // Given
        let images = [testImage!, UIImage(), testImage!]
        var progressMessages: [String] = []
        
        // When
        let enhancedImages = try await enhancer.enhanceImages(images) { message in
            progressMessages.append(message)
        }
        
        // Then
        XCTAssertEqual(enhancedImages.count, 3)
        XCTAssertTrue(progressMessages.contains { $0.contains("Warning: Failed to enhance") })
        
        // First and third images should be enhanced, second should be original
        XCTAssertGreaterThan(enhancedImages[0].size.width, 0)
        XCTAssertEqual(enhancedImages[1], UIImage()) // Original invalid image
        XCTAssertGreaterThan(enhancedImages[2].size.width, 0)
    }
    
    func testEnhanceImage_Performance() async throws {
        // Given
        let largeImage = createLargeTestImage()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await enhancer.enhanceImage(largeImage)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(timeElapsed, 5.0, "Enhancement should complete within 5 seconds")
    }
    
    func testEnhancementSettings_DefaultConfiguration() {
        // Given
        let defaultSettings = DocumentImageEnhancer.EnhancementSettings.default
        
        // Then
        XCTAssertEqual(defaultSettings.noiseLevel, 0.02)
        XCTAssertEqual(defaultSettings.sharpness, 0.8)
        XCTAssertEqual(defaultSettings.contrast, 1.8)
        XCTAssertEqual(defaultSettings.brightness, 0.2)
        XCTAssertEqual(defaultSettings.targetWidth, 1600)
    }
    
    func testEnhancementSettings_DocumentOptimized() {
        // Given
        let optimizedSettings = DocumentImageEnhancer.EnhancementSettings.documentOptimized
        
        // Then
        XCTAssertEqual(optimizedSettings.noiseLevel, 0.01)
        XCTAssertEqual(optimizedSettings.sharpness, 1.0)
        XCTAssertEqual(optimizedSettings.contrast, 2.0)
        XCTAssertEqual(optimizedSettings.brightness, 0.1)
        XCTAssertEqual(optimizedSettings.targetWidth, 1800)
    }
    
    // MARK: - Integration Tests
    
    func testEnhanceImage_ResolutionOptimization() async throws {
        // Given
        let smallImage = createSmallTestImage() // 400x300
        let largeImage = createVeryLargeTestImage() // 3000x2000
        
        // When
        let enhancedSmall = try await enhancer.enhanceImage(smallImage)
        let enhancedLarge = try await enhancer.enhanceImage(largeImage)
        
        // Then
        // Small image should be upscaled closer to target (1600px)
        XCTAssertGreaterThan(enhancedSmall.size.width, smallImage.size.width)
        
        // Large image should be downscaled closer to target (1600px)
        XCTAssertLessThan(enhancedLarge.size.width, largeImage.size.width)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 800, height: 600)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Create a white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Add some text-like elements
        context.setFillColor(UIColor.black.cgColor)
        for i in 0..<10 {
            let rect = CGRect(x: 50, y: 50 + i * 50, width: 200, height: 20)
            context.fill(rect)
        }
        
        // Add some table-like structure
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2.0)
        
        // Draw grid
        for i in 0...5 {
            // Horizontal lines
            context.move(to: CGPoint(x: 300, y: 50 + i * 100))
            context.addLine(to: CGPoint(x: 700, y: 50 + i * 100))
            context.strokePath()
            
            // Vertical lines
            if i <= 4 {
                context.move(to: CGPoint(x: 300 + i * 100, y: 50))
                context.addLine(to: CGPoint(x: 300 + i * 100, y: 550))
                context.strokePath()
            }
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createLargeTestImage() -> UIImage {
        let size = CGSize(width: 2000, height: 1500)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createSmallTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createVeryLargeTestImage() -> UIImage {
        let size = CGSize(width: 3000, height: 2000)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
} 