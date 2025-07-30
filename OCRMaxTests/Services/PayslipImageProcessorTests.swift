//
//  PayslipImageProcessorTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 02/01/25.
//

import XCTest
@testable import OCRMax
import UIKit

final class PayslipImageProcessorTests: XCTestCase {
    
    var processor: PayslipImageProcessor!
    var mockEnhancer: MockDocumentImageEnhancer!
    var testPayslipImage: UIImage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockEnhancer = MockDocumentImageEnhancer()
        processor = PayslipImageProcessor(documentEnhancer: mockEnhancer)
        testPayslipImage = createPayslipTestImage()
    }
    
    override func tearDownWithError() throws {
        processor = nil
        mockEnhancer = nil
        testPayslipImage = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Test Methods
    
    func testProcessPayslipImage_ValidImage_ReturnsProcessedImage() async throws {
        // Given
        let originalImage = testPayslipImage!
        mockEnhancer.enhanceImageResult = originalImage
        
        // When
        let processedImage = try await processor.processPayslipImage(originalImage)
        
        // Then
        XCTAssertNotNil(processedImage)
        XCTAssertGreaterThan(processedImage.size.width, 0)
        XCTAssertGreaterThan(processedImage.size.height, 0)
        XCTAssertTrue(mockEnhancer.enhanceImageCalled)
    }
    
    func testProcessPayslipImage_InvalidImage_ThrowsError() async {
        // Given
        let invalidImage = UIImage()
        mockEnhancer.enhanceImageResult = invalidImage
        
        // When & Then
        do {
            _ = try await processor.processPayslipImage(invalidImage)
            XCTFail("Should have thrown an error for invalid image")
        } catch PayslipImageProcessor.ProcessingError.invalidImage {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDetectTableStructure_PayslipImage_ReturnsTableStructure() async throws {
        // Given
        let payslipImage = testPayslipImage!
        mockEnhancer.enhanceImageResult = payslipImage
        
        // When
        let tableStructure = try await processor.detectTableStructure(in: payslipImage)
        
        // Then
        XCTAssertNotNil(tableStructure)
        XCTAssertGreaterThan(tableStructure.horizontalLines.count, 0)
        XCTAssertGreaterThan(tableStructure.verticalLines.count, 0)
        XCTAssertGreaterThan(tableStructure.tableCells.count, 0)
        XCTAssertEqual(tableStructure.imageSize, payslipImage.size)
    }
    
    func testDetectTableStructure_HeaderRegionIdentification() async throws {
        // Given
        let payslipImage = testPayslipImage!
        mockEnhancer.enhanceImageResult = payslipImage
        
        // When
        let tableStructure = try await processor.detectTableStructure(in: payslipImage)
        
        // Then
        let headerRegion = tableStructure.headerRegion
        XCTAssertGreaterThan(headerRegion.height, 0)
        XCTAssertGreaterThan(headerRegion.width, 0)
        
        // Header should be in the upper portion of the image
        let imageHeight = payslipImage.size.height
        XCTAssertGreaterThan(headerRegion.minY, imageHeight * 0.6) // Header is in top 40%
    }
    
    func testLineSegment_Properties() {
        // Given
        let start = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 100, y: 0)
        let line = LineSegment(start: start, end: end, strength: 0.8)
        
        // Then
        XCTAssertEqual(line.length, 100.0, accuracy: 0.1)
        XCTAssertTrue(line.isHorizontal)
        XCTAssertEqual(line.strength, 0.8)
    }
    
    func testLineSegment_VerticalLine() {
        // Given
        let start = CGPoint(x: 50, y: 0)
        let end = CGPoint(x: 50, y: 200)
        let line = LineSegment(start: start, end: end, strength: 0.7)
        
        // Then
        XCTAssertEqual(line.length, 200.0, accuracy: 0.1)
        XCTAssertFalse(line.isHorizontal)
    }
    
    func testTableCell_Properties() {
        // Given
        let bounds = CGRect(x: 10, y: 20, width: 100, height: 50)
        let cell = TableCell(bounds: bounds, row: 1, column: 2, confidence: 0.9)
        
        // Then
        XCTAssertEqual(cell.center, CGPoint(x: 60, y: 45))
        XCTAssertEqual(cell.area, 5000.0)
        XCTAssertEqual(cell.row, 1)
        XCTAssertEqual(cell.column, 2)
        XCTAssertEqual(cell.confidence, 0.9)
    }
    
    func testPayslipTableStructure_Initialization() {
        // Given
        let horizontalLines = [LineSegment(start: CGPoint(x: 0, y: 100), end: CGPoint(x: 800, y: 100), strength: 0.8)]
        let verticalLines = [LineSegment(start: CGPoint(x: 100, y: 0), end: CGPoint(x: 100, y: 600), strength: 0.7)]
        let headerRegion = CGRect(x: 0, y: 500, width: 800, height: 100)
        let tableCells = [TableCell(bounds: CGRect(x: 0, y: 0, width: 100, height: 100), row: 0, column: 0, confidence: 0.9)]
        let imageSize = CGSize(width: 800, height: 600)
        
        // When
        let structure = PayslipTableStructure(
            horizontalLines: horizontalLines,
            verticalLines: verticalLines,
            headerRegion: headerRegion,
            tableCells: tableCells,
            imageSize: imageSize
        )
        
        // Then
        XCTAssertEqual(structure.horizontalLines.count, 1)
        XCTAssertEqual(structure.verticalLines.count, 1)
        XCTAssertEqual(structure.headerRegion, headerRegion)
        XCTAssertEqual(structure.tableCells.count, 1)
        XCTAssertEqual(structure.imageSize, imageSize)
    }
    
    // MARK: - Performance Tests
    
    func testProcessPayslipImage_Performance() async throws {
        // Given
        let largePayslipImage = createLargePayslipTestImage()
        mockEnhancer.enhanceImageResult = largePayslipImage
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await processor.processPayslipImage(largePayslipImage)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(timeElapsed, 10.0, "Payslip processing should complete within 10 seconds")
    }
    
    func testDetectTableStructure_Performance() async throws {
        // Given
        let complexPayslipImage = createComplexPayslipTestImage()
        mockEnhancer.enhanceImageResult = complexPayslipImage
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await processor.detectTableStructure(in: complexPayslipImage)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(timeElapsed, 8.0, "Table structure detection should complete within 8 seconds")
    }
    
    // MARK: - Helper Methods
    
    private func createPayslipTestImage() -> UIImage {
        let size = CGSize(width: 800, height: 1000)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Create white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw header section
        context.setFillColor(UIColor.lightGray.cgColor)
        context.fill(CGRect(x: 0, y: 850, width: 800, height: 150))
        
        // Add payslip title
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 250, y: 900, width: 300, height: 30))
        
        // Draw table structure
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2.0)
        
        // Draw horizontal lines (table rows)
        for i in 0...10 {
            let y = CGFloat(50 + i * 70)
            context.move(to: CGPoint(x: 50, y: y))
            context.addLine(to: CGPoint(x: 750, y: y))
            context.strokePath()
        }
        
        // Draw vertical lines (table columns)
        for i in 0...5 {
            let x = CGFloat(50 + i * 140)
            context.move(to: CGPoint(x: x, y: 50))
            context.addLine(to: CGPoint(x: x, y: 750))
            context.strokePath()
        }
        
        // Add some text-like elements in cells
        context.setFillColor(UIColor.black.cgColor)
        for row in 0..<10 {
            for col in 0..<5 {
                let x = CGFloat(60 + col * 140)
                let y = CGFloat(60 + row * 70)
                context.fill(CGRect(x: x, y: y, width: 120, height: 15))
            }
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createLargePayslipTestImage() -> UIImage {
        let size = CGSize(width: 1600, height: 2000)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createComplexPayslipTestImage() -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Create white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw complex table with merged cells and irregular structure
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.0)
        
        // Draw a more complex grid pattern
        for i in 0...20 {
            let y = CGFloat(50 + i * 60)
            context.move(to: CGPoint(x: 50, y: y))
            context.addLine(to: CGPoint(x: 1150, y: y))
            context.strokePath()
        }
        
        for i in 0...8 {
            let x = CGFloat(50 + i * 137.5)
            context.move(to: CGPoint(x: x, y: 50))
            context.addLine(to: CGPoint(x: x, y: 1250))
            context.strokePath()
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}

// MARK: - Mock DocumentImageEnhancer

class MockDocumentImageEnhancer: DocumentImageEnhancer {
    var enhanceImageCalled = false
    var enhanceImageResult: UIImage?
    var enhanceImagesResults: [UIImage] = []
    
    override func enhanceImage(_ image: UIImage) async throws -> UIImage {
        enhanceImageCalled = true
        
        if let result = enhanceImageResult {
            return result
        }
        
        return try await super.enhanceImage(image)
    }
    
    override func enhanceImages(_ images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> [UIImage] {
        if !enhanceImagesResults.isEmpty {
            return enhanceImagesResults
        }
        
        return try await super.enhanceImages(images, progressHandler: progressHandler)
    }
} 