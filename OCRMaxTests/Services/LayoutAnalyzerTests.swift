//
//  LayoutAnalyzerTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import XCTest
@testable import OCRMax

final class LayoutAnalyzerTests: XCTestCase {
    
    var layoutAnalyzer: LayoutAnalyzer!
    
    override func setUp() {
        super.setUp()
        layoutAnalyzer = LayoutAnalyzer()
    }
    
    override func tearDown() {
        layoutAnalyzer = nil
        super.tearDown()
    }
    
    // MARK: - TextBlock Positioning Tests
    
    func testTextBlockSortingByPosition() {
        let blocks = [
            TextBlock(text: "Bottom Right", boundingBox: CGRect(x: 200, y: 300, width: 100, height: 20), confidence: 0.9),
            TextBlock(text: "Top Left", boundingBox: CGRect(x: 50, y: 50, width: 80, height: 20), confidence: 0.9),
            TextBlock(text: "Top Right", boundingBox: CGRect(x: 200, y: 50, width: 90, height: 20), confidence: 0.9),
            TextBlock(text: "Bottom Left", boundingBox: CGRect(x: 50, y: 300, width: 110, height: 20), confidence: 0.9)
        ]
        
        let sortedBlocks = TextBlock.sortedByPosition(blocks)
        
        XCTAssertEqual(sortedBlocks[0].text, "Top Left")
        XCTAssertEqual(sortedBlocks[1].text, "Top Right")
        XCTAssertEqual(sortedBlocks[2].text, "Bottom Left")
        XCTAssertEqual(sortedBlocks[3].text, "Bottom Right")
    }
    
    func testSameRowDetection() {
        let block1 = TextBlock(text: "Left", boundingBox: CGRect(x: 50, y: 100, width: 80, height: 20), confidence: 0.9)
        let block2 = TextBlock(text: "Right", boundingBox: CGRect(x: 200, y: 105, width: 90, height: 20), confidence: 0.9)
        let block3 = TextBlock(text: "Below", boundingBox: CGRect(x: 50, y: 150, width: 100, height: 20), confidence: 0.9)
        
        XCTAssertTrue(block1.isInSameRow(as: block2))
        XCTAssertFalse(block1.isInSameRow(as: block3))
    }
    
    func testGroupByRows() {
        let blocks = [
            TextBlock(text: "Row1 Left", boundingBox: CGRect(x: 50, y: 100, width: 80, height: 20), confidence: 0.9),
            TextBlock(text: "Row1 Right", boundingBox: CGRect(x: 200, y: 105, width: 90, height: 20), confidence: 0.9),
            TextBlock(text: "Row2 Left", boundingBox: CGRect(x: 50, y: 150, width: 100, height: 20), confidence: 0.9),
            TextBlock(text: "Row2 Right", boundingBox: CGRect(x: 200, y: 155, width: 110, height: 20), confidence: 0.9)
        ]
        
        let rows = TextBlock.groupByRows(blocks)
        
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].count, 2)
        XCTAssertEqual(rows[1].count, 2)
        XCTAssertEqual(rows[0][0].text, "Row1 Left")
        XCTAssertEqual(rows[0][1].text, "Row1 Right")
    }
    
    // MARK: - Column Detection Tests
    
    func testSingleColumnDetection() {
        let blocks = [
            TextBlock(text: "Line 1", boundingBox: CGRect(x: 50, y: 50, width: 200, height: 20), confidence: 0.9),
            TextBlock(text: "Line 2", boundingBox: CGRect(x: 50, y: 80, width: 180, height: 20), confidence: 0.9),
            TextBlock(text: "Line 3", boundingBox: CGRect(x: 50, y: 110, width: 220, height: 20), confidence: 0.9)
        ]
        
        let columns = layoutAnalyzer.detectColumns(in: blocks)
        
        XCTAssertEqual(columns.count, 1)
        XCTAssertEqual(columns[0].textBlocks.count, 3)
    }
    
    func testTwoColumnDetection() {
        let blocks = [
            TextBlock(text: "Left Col 1", boundingBox: CGRect(x: 50, y: 50, width: 150, height: 20), confidence: 0.9),
            TextBlock(text: "Right Col 1", boundingBox: CGRect(x: 250, y: 50, width: 150, height: 20), confidence: 0.9),
            TextBlock(text: "Left Col 2", boundingBox: CGRect(x: 50, y: 80, width: 140, height: 20), confidence: 0.9),
            TextBlock(text: "Right Col 2", boundingBox: CGRect(x: 250, y: 80, width: 160, height: 20), confidence: 0.9)
        ]
        
        let columns = layoutAnalyzer.detectColumns(in: blocks)
        
        XCTAssertEqual(columns.count, 2)
        XCTAssertEqual(columns[0].textBlocks.count, 2)
        XCTAssertEqual(columns[1].textBlocks.count, 2)
    }
    
    // MARK: - Spacing Analysis Tests
    
    func testSpacingCalculation() {
        let blocks = [
            TextBlock(text: "Line 1", boundingBox: CGRect(x: 50, y: 50, width: 100, height: 20), confidence: 0.9),
            TextBlock(text: "Line 2", boundingBox: CGRect(x: 50, y: 85, width: 100, height: 20), confidence: 0.9),
            TextBlock(text: "Line 3", boundingBox: CGRect(x: 50, y: 120, width: 100, height: 20), confidence: 0.9)
        ]
        
        let spacing = layoutAnalyzer.calculateSpacing(between: blocks)
        
        XCTAssertEqual(spacing.averageLineSpacing, 15.0, accuracy: 1.0)
        XCTAssertGreaterThan(spacing.averageWordSpacing, 0)
    }
    
    // MARK: - Text Grouping Tests
    
    func testParagraphGrouping() {
        let blocks = [
            TextBlock(text: "simple text", boundingBox: CGRect(x: 50, y: 50, width: 100, height: 10), confidence: 0.9)
        ]
        
        let groups = layoutAnalyzer.groupTextBlocks(blocks)
        
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.groupType, .paragraph)
    }
    
    func testHeaderDetection() {
        let blocks = [
            TextBlock(text: "CHAPTER 1: INTRODUCTION", boundingBox: CGRect(x: 100, y: 50, width: 250, height: 30), confidence: 0.95),
            TextBlock(text: "This is the first paragraph of the chapter.", boundingBox: CGRect(x: 50, y: 100, width: 300, height: 20), confidence: 0.9),
            TextBlock(text: "It continues with more detailed information.", boundingBox: CGRect(x: 50, y: 125, width: 290, height: 20), confidence: 0.9)
        ]
        
        let groups = layoutAnalyzer.groupTextBlocks(blocks)
        
        let headerGroups = groups.filter { $0.groupType == .header }
        XCTAssertGreaterThan(headerGroups.count, 0)
    }
    
    // MARK: - Layout Analysis Integration Tests
    
    func testCompleteLayoutAnalysis() {
        let blocks = createComplexDocumentBlocks()
        
        let analysis = layoutAnalyzer.analyzeLayout(from: blocks)
        
        XCTAssertGreaterThan(analysis.columns.count, 0)
        XCTAssertGreaterThan(analysis.textGroups.count, 0)
        XCTAssertGreaterThan(analysis.spacing.averageLineSpacing, 0)
        XCTAssertGreaterThan(analysis.suggestedIndentation.count, 0)
    }
    
    func testEmptyTextBlocksHandling() {
        let emptyBlocks: [TextBlock] = []
        
        let analysis = layoutAnalyzer.analyzeLayout(from: emptyBlocks)
        
        XCTAssertEqual(analysis.columns.count, 0)
        XCTAssertEqual(analysis.textGroups.count, 0)
        XCTAssertEqual(analysis.suggestedIndentation.count, 0)
    }
    
    func testSingleTextBlockHandling() {
        let singleBlock = [TextBlock(text: "Single line", boundingBox: CGRect(x: 50, y: 50, width: 200, height: 20), confidence: 0.9)]
        
        let analysis = layoutAnalyzer.analyzeLayout(from: singleBlock)
        
        XCTAssertEqual(analysis.columns.count, 1)
        XCTAssertEqual(analysis.textGroups.count, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createComplexDocumentBlocks() -> [TextBlock] {
        return [
            TextBlock(text: "DOCUMENT TITLE", boundingBox: CGRect(x: 100, y: 50, width: 200, height: 30), confidence: 0.95),
            TextBlock(text: "This is the first paragraph of the document.", boundingBox: CGRect(x: 50, y: 100, width: 300, height: 20), confidence: 0.9),
            TextBlock(text: "It contains multiple sentences that span", boundingBox: CGRect(x: 50, y: 125, width: 280, height: 20), confidence: 0.9),
            TextBlock(text: "across several lines of text.", boundingBox: CGRect(x: 50, y: 150, width: 200, height: 20), confidence: 0.9),
            TextBlock(text: "Second paragraph begins here.", boundingBox: CGRect(x: 50, y: 190, width: 250, height: 20), confidence: 0.9),
            TextBlock(text: "Column 1 text", boundingBox: CGRect(x: 50, y: 250, width: 150, height: 20), confidence: 0.9),
            TextBlock(text: "Column 2 text", boundingBox: CGRect(x: 250, y: 250, width: 150, height: 20), confidence: 0.9),
            TextBlock(text: "More column 1", boundingBox: CGRect(x: 50, y: 275, width: 140, height: 20), confidence: 0.9),
            TextBlock(text: "More column 2", boundingBox: CGRect(x: 250, y: 275, width: 160, height: 20), confidence: 0.9)
        ]
    }
}