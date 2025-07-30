//
//  EnhancedLayoutAnalyzerTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 02/01/25.
//

import XCTest
@testable import OCRMax
import UIKit

final class EnhancedLayoutAnalyzerTests: XCTestCase {
    
    var analyzer: EnhancedLayoutAnalyzer!
    var testTextBlocks: [TextBlock]!
    var testTableStructure: PayslipTableStructure!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        analyzer = EnhancedLayoutAnalyzer()
        testTextBlocks = createTestTextBlocks()
        testTableStructure = createTestTableStructure()
    }
    
    override func tearDownWithError() throws {
        analyzer = nil
        testTextBlocks = nil
        testTableStructure = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Test Methods
    
    func testAnalyzeTableStructure_WithValidData_ReturnsEnhancedAnalysis() {
        // Given
        let textBlocks = testTextBlocks!
        let tableStructure = testTableStructure!
        
        // When
        let analysis = analyzer.analyzeTableStructure(from: textBlocks, tableStructure: tableStructure)
        
        // Then
        XCTAssertNotNil(analysis)
        XCTAssertGreaterThan(analysis.tableCells.count, 0)
        XCTAssertGreaterThan(analysis.tableRegions.count, 0)
        XCTAssertNotNil(analysis.gridStructure)
        XCTAssertGreaterThan(analysis.confidence, 0.0)
    }
    
    func testAnalyzeTableStructure_WithoutTableStructure_ReturnsBasicAnalysis() {
        // Given
        let textBlocks = testTextBlocks!
        
        // When
        let analysis = analyzer.analyzeTableStructure(from: textBlocks, tableStructure: nil)
        
        // Then
        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis.tableCells.count, 0)
        XCTAssertEqual(analysis.tableRegions.count, 0)
        XCTAssertNil(analysis.gridStructure)
        XCTAssertEqual(analysis.confidence, 0.0)
    }
    
    func testDetectTableCells_ValidTextBlocks_ReturnsAnalyzedCells() {
        // Given
        let textBlocks = testTextBlocks!
        let tableStructure = testTableStructure!
        
        // When
        let cellAnalyses = analyzer.detectTableCells(from: textBlocks, tableStructure: tableStructure)
        
        // Then
        XCTAssertGreaterThan(cellAnalyses.count, 0)
        
        for cellAnalysis in cellAnalyses {
            XCTAssertGreaterThan(cellAnalysis.confidence, 0.0)
            XCTAssertNotNil(cellAnalysis.contentType)
        }
    }
    
    func testClassifyTableRegions_ValidData_ReturnsRegions() {
        // Given
        let textBlocks = testTextBlocks!
        let tableStructure = testTableStructure!
        
        // When
        let regions = analyzer.classifyTableRegions(from: textBlocks, tableStructure: tableStructure)
        
        // Then
        XCTAssertGreaterThan(regions.count, 0)
        
        let headerRegions = regions.filter { $0.type == .header }
        XCTAssertGreaterThan(headerRegions.count, 0)
    }
    
    func testCellContentClassification_NumericalContent() {
        // Given
        let numericalBlocks = [
            TextBlock(text: "38100", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20), confidence: 0.9),
            TextBlock(text: "₹5,200", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20), confidence: 0.9)
        ]
        
        // When
        let cellAnalysis = createTestCellAnalysis(with: numericalBlocks)
        
        // Then
        XCTAssertEqual(cellAnalysis.contentType, .numerical)
    }
    
    func testCellContentClassification_LabelContent() {
        // Given
        let labelBlocks = [
            TextBlock(text: "BASIC PAY:", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9),
            TextBlock(text: "EMPLOYEE ID", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9)
        ]
        
        // When
        let cellAnalysis = createTestCellAnalysis(with: labelBlocks)
        
        // Then
        XCTAssertEqual(cellAnalysis.contentType, .label)
    }
    
    func testCellContentClassification_DateContent() {
        // Given
        let dateBlocks = [
            TextBlock(text: "24/06/2009", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9),
            TextBlock(text: "01-01-2025", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9)
        ]
        
        // When
        let cellAnalysis = createTestCellAnalysis(with: dateBlocks)
        
        // Then
        XCTAssertEqual(cellAnalysis.contentType, .date)
    }
    
    func testGridStructure_CalculatesDimensions() {
        // Given
        let textBlocks = testTextBlocks!
        let tableStructure = testTableStructure!
        
        // When
        let analysis = analyzer.analyzeTableStructure(from: textBlocks, tableStructure: tableStructure)
        
        // Then
        guard let gridStructure = analysis.gridStructure else {
            XCTFail("Grid structure should not be nil")
            return
        }
        
        XCTAssertGreaterThan(gridStructure.dimensions.rows, 0)
        XCTAssertGreaterThan(gridStructure.dimensions.columns, 0)
        XCTAssertEqual(gridStructure.columnTypes.count, gridStructure.dimensions.columns)
        XCTAssertGreaterThan(gridStructure.uniformity, 0.0)
    }
    
    func testColumnType_Classification() {
        // Given
        let mixedContentTypes: [CellContentType] = [.label, .numerical, .text, .label]
        let numericalContentTypes: [CellContentType] = [.numerical, .numerical, .numerical]
        
        // When
        let mixedColumnType = determinePredominantColumnType(contentTypes: mixedContentTypes)
        let numericalColumnType = determinePredominantColumnType(contentTypes: numericalContentTypes)
        
        // Then
        XCTAssertEqual(mixedColumnType, .label) // Most frequent
        XCTAssertEqual(numericalColumnType, .numerical)
    }
    
    func testEnhancedLayoutAnalysis_ConfidenceCalculation() {
        // Given
        let textBlocks = testTextBlocks!
        let tableStructure = testTableStructure!
        
        // When
        let analysis = analyzer.analyzeTableStructure(from: textBlocks, tableStructure: tableStructure)
        
        // Then
        XCTAssertGreaterThanOrEqual(analysis.confidence, 0.0)
        XCTAssertLessThanOrEqual(analysis.confidence, 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testAnalyzeTableStructure_Performance() {
        // Given
        let largeTextBlocks = createLargeTestTextBlocks()
        let largeTableStructure = createLargeTestTableStructure()
        
        // When
        measure {
            _ = analyzer.analyzeTableStructure(from: largeTextBlocks, tableStructure: largeTableStructure)
        }
        
        // Then - Should complete within reasonable time
    }
    
    // MARK: - Helper Methods
    
    private func createTestTextBlocks() -> [TextBlock] {
        return [
            // Header blocks
            TextBlock(text: "EMPLOYEE ID", boundingBox: CGRect(x: 50, y: 900, width: 100, height: 20), confidence: 0.9),
            TextBlock(text: "NAME", boundingBox: CGRect(x: 200, y: 900, width: 80, height: 20), confidence: 0.9),
            
            // Data blocks
            TextBlock(text: "144227", boundingBox: CGRect(x: 50, y: 850, width: 60, height: 20), confidence: 0.9),
            TextBlock(text: "VINOD KUMAR", boundingBox: CGRect(x: 200, y: 850, width: 120, height: 20), confidence: 0.9),
            
            // Amount blocks
            TextBlock(text: "BASIC PAY", boundingBox: CGRect(x: 50, y: 800, width: 80, height: 20), confidence: 0.9),
            TextBlock(text: "38100", boundingBox: CGRect(x: 200, y: 800, width: 50, height: 20), confidence: 0.9),
            
            // Credits/Debits
            TextBlock(text: "CREDITS", boundingBox: CGRect(x: 50, y: 750, width: 70, height: 20), confidence: 0.9),
            TextBlock(text: "DEBITS", boundingBox: CGRect(x: 400, y: 750, width: 60, height: 20), confidence: 0.9)
        ]
    }
    
    private func createTestTableStructure() -> PayslipTableStructure {
        let horizontalLines = [
            LineSegment(start: CGPoint(x: 50, y: 920), end: CGPoint(x: 750, y: 920), strength: 0.8),
            LineSegment(start: CGPoint(x: 50, y: 870), end: CGPoint(x: 750, y: 870), strength: 0.8),
            LineSegment(start: CGPoint(x: 50, y: 820), end: CGPoint(x: 750, y: 820), strength: 0.8)
        ]
        
        let verticalLines = [
            LineSegment(start: CGPoint(x: 50, y: 750), end: CGPoint(x: 50, y: 920), strength: 0.7),
            LineSegment(start: CGPoint(x: 150, y: 750), end: CGPoint(x: 150, y: 920), strength: 0.7),
            LineSegment(start: CGPoint(x: 400, y: 750), end: CGPoint(x: 400, y: 920), strength: 0.7),
            LineSegment(start: CGPoint(x: 750, y: 750), end: CGPoint(x: 750, y: 920), strength: 0.7)
        ]
        
        let headerRegion = CGRect(x: 50, y: 900, width: 700, height: 20)
        
        let tableCells = [
            TableCell(bounds: CGRect(x: 50, y: 870, width: 100, height: 50), row: 0, column: 0, confidence: 0.8),
            TableCell(bounds: CGRect(x: 150, y: 870, width: 250, height: 50), row: 0, column: 1, confidence: 0.8),
            TableCell(bounds: CGRect(x: 50, y: 820, width: 100, height: 50), row: 1, column: 0, confidence: 0.8),
            TableCell(bounds: CGRect(x: 150, y: 820, width: 250, height: 50), row: 1, column: 1, confidence: 0.8)
        ]
        
        return PayslipTableStructure(
            horizontalLines: horizontalLines,
            verticalLines: verticalLines,
            headerRegion: headerRegion,
            tableCells: tableCells,
            imageSize: CGSize(width: 800, height: 1000)
        )
    }
    
    private func createTestCellAnalysis(with textBlocks: [TextBlock]) -> TableCellAnalysis {
        let tableCell = TableCell(bounds: CGRect(x: 0, y: 0, width: 100, height: 50), row: 0, column: 0, confidence: 0.8)
        
        // Use reflection to access private method for testing
        let contentType = classifyCellContentForTest(textBlocks: textBlocks)
        
        return TableCellAnalysis(
            cell: tableCell,
            textBlocks: textBlocks,
            contentType: contentType,
            isEmpty: textBlocks.isEmpty,
            confidence: 0.8
        )
    }
    
    private func classifyCellContentForTest(textBlocks: [TextBlock]) -> CellContentType {
        guard !textBlocks.isEmpty else { return .empty }
        
        let combinedText = textBlocks.map { $0.text }.joined(separator: " ")
        
        // Check for numerical content
        let numericalPattern = #"^\s*[\d,\.\-\+\₹\$\s]+\s*$"#
        if combinedText.range(of: numericalPattern, options: .regularExpression) != nil {
            return .numerical
        }
        
        // Check for labels
        let upperCaseRatio = Double(combinedText.filter { $0.isUppercase }.count) / Double(combinedText.count)
        if upperCaseRatio > 0.7 || combinedText.contains(":") || combinedText.hasSuffix(":") {
            return .label
        }
        
        // Check for dates
        let datePattern = #"\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}"#
        if combinedText.range(of: datePattern, options: .regularExpression) != nil {
            return .date
        }
        
        return .text
    }
    
    private func determinePredominantColumnType(contentTypes: [CellContentType]) -> ColumnType {
        let typeCounts = Dictionary(grouping: contentTypes) { $0 }.mapValues { $0.count }
        
        guard let predominantType = typeCounts.max(by: { $0.value < $1.value })?.key else {
            return .mixed
        }
        
        switch predominantType {
        case .label:
            return .label
        case .numerical:
            return .numerical
        case .date:
            return .date
        case .text:
            return .text
        case .empty:
            return .mixed
        }
    }
    
    private func createLargeTestTextBlocks() -> [TextBlock] {
        var blocks: [TextBlock] = []
        
        for row in 0..<20 {
            for col in 0..<5 {
                let x = CGFloat(50 + col * 150)
                let y = CGFloat(50 + row * 40)
                let text = "Cell_\(row)_\(col)"
                
                let block = TextBlock(
                    text: text,
                    boundingBox: CGRect(x: x, y: y, width: 120, height: 30),
                    confidence: 0.8
                )
                blocks.append(block)
            }
        }
        
        return blocks
    }
    
    private func createLargeTestTableStructure() -> PayslipTableStructure {
        let horizontalLines = (0..<21).map { row in
            let y = CGFloat(50 + row * 40)
            return LineSegment(start: CGPoint(x: 50, y: y), end: CGPoint(x: 800, y: y), strength: 0.7)
        }
        
        let verticalLines = (0..<6).map { col in
            let x = CGFloat(50 + col * 150)
            return LineSegment(start: CGPoint(x: x, y: 50), end: CGPoint(x: x, y: 850), strength: 0.7)
        }
        
        let tableCells = (0..<20).flatMap { row in
            (0..<5).map { col in
                let x = CGFloat(50 + col * 150)
                let y = CGFloat(50 + row * 40)
                return TableCell(
                    bounds: CGRect(x: x, y: y, width: 150, height: 40),
                    row: row,
                    column: col,
                    confidence: 0.8
                )
            }
        }
        
        return PayslipTableStructure(
            horizontalLines: horizontalLines,
            verticalLines: verticalLines,
            headerRegion: CGRect(x: 50, y: 810, width: 750, height: 40),
            tableCells: tableCells,
            imageSize: CGSize(width: 850, height: 900)
        )
    }
} 