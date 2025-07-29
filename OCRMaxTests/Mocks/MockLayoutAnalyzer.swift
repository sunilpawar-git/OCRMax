//
//  MockLayoutAnalyzer.swift
//  OCRMaxTests
//
//  Created by Claude on 29/07/25.
//

import Foundation
import CoreGraphics
@testable import OCRMax

final class MockLayoutAnalyzer: LayoutAnalyzerProtocol {
    
    // MARK: - Call Tracking
    var analyzeLayoutCallCount = 0
    var detectColumnsCallCount = 0
    var calculateSpacingCallCount = 0
    var groupTextBlocksCallCount = 0
    
    // MARK: - Mock Data
    var mockLayoutAnalysis: LayoutAnalysis?
    var mockColumns: [ColumnGroup] = []
    var mockSpacing: SpacingInfo?
    var mockTextGroups: [TextGroup] = []
    
    // MARK: - Captured Parameters
    var lastAnalyzedTextBlocks: [TextBlock] = []
    var lastDetectedTextBlocks: [TextBlock] = []
    var lastSpacingTextBlocks: [TextBlock] = []
    var lastGroupedTextBlocks: [TextBlock] = []
    
    // MARK: - LayoutAnalyzerProtocol Methods
    
    func analyzeLayout(from textBlocks: [TextBlock]) -> LayoutAnalysis {
        analyzeLayoutCallCount += 1
        lastAnalyzedTextBlocks = textBlocks
        
        // Return mock layout analysis if provided
        if let mockAnalysis = mockLayoutAnalysis {
            return mockAnalysis
        }
        
        // Create default layout analysis
        let columns = detectColumns(in: textBlocks)
        let spacing = calculateSpacing(between: textBlocks)
        let textGroups = groupTextBlocks(textBlocks)
        let indentation = createDefaultIndentation(for: textBlocks)
        
        return LayoutAnalysis(
            columns: columns,
            spacing: spacing,
            textGroups: textGroups,
            suggestedIndentation: indentation
        )
    }
    
    func detectColumns(in textBlocks: [TextBlock]) -> [ColumnGroup] {
        detectColumnsCallCount += 1
        lastDetectedTextBlocks = textBlocks
        
        // Return mock columns if provided
        if !mockColumns.isEmpty {
            return mockColumns
        }
        
        // Create default single column
        guard !textBlocks.isEmpty else { return [] }
        
        let boundingBox = calculateBoundingBox(for: textBlocks)
        return [ColumnGroup(textBlocks: textBlocks, boundingBox: boundingBox, columnIndex: 0)]
    }
    
    func calculateSpacing(between textBlocks: [TextBlock]) -> SpacingInfo {
        calculateSpacingCallCount += 1
        lastSpacingTextBlocks = textBlocks
        
        // Return mock spacing if provided
        if let mockSpacingInfo = mockSpacing {
            return mockSpacingInfo
        }
        
        // Create default spacing
        return SpacingInfo(
            averageLineSpacing: 15.0,
            averageWordSpacing: 5.0,
            paragraphSpacing: 22.5
        )
    }
    
    func groupTextBlocks(_ textBlocks: [TextBlock]) -> [TextGroup] {
        groupTextBlocksCallCount += 1
        lastGroupedTextBlocks = textBlocks
        
        // Return mock text groups if provided
        if !mockTextGroups.isEmpty {
            return mockTextGroups
        }
        
        // Create default text groups
        guard !textBlocks.isEmpty else { return [] }
        
        return [TextGroup(blocks: textBlocks, groupType: .paragraph, confidence: 0.9)]
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        analyzeLayoutCallCount = 0
        detectColumnsCallCount = 0
        calculateSpacingCallCount = 0
        groupTextBlocksCallCount = 0
        
        mockLayoutAnalysis = nil
        mockColumns = []
        mockSpacing = nil
        mockTextGroups = []
        
        lastAnalyzedTextBlocks = []
        lastDetectedTextBlocks = []
        lastSpacingTextBlocks = []
        lastGroupedTextBlocks = []
    }
    
    func setMockLayoutAnalysis(_ analysis: LayoutAnalysis) {
        mockLayoutAnalysis = analysis
    }
    
    func setMockColumns(_ columns: [ColumnGroup]) {
        mockColumns = columns
    }
    
    func setMockSpacing(_ spacing: SpacingInfo) {
        mockSpacing = spacing
    }
    
    func setMockTextGroups(_ textGroups: [TextGroup]) {
        mockTextGroups = textGroups
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateBoundingBox(for blocks: [TextBlock]) -> CGRect {
        guard !blocks.isEmpty else { return .zero }
        
        let minX = blocks.min { $0.minX < $1.minX }?.minX ?? 0
        let minY = blocks.min { $0.minY < $1.minY }?.minY ?? 0
        let maxX = blocks.max { $0.maxX < $1.maxX }?.maxX ?? 0
        let maxY = blocks.max { $0.maxY < $1.maxY }?.maxY ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func createDefaultIndentation(for textBlocks: [TextBlock]) -> [IndentationLevel] {
        return textBlocks.map { block in
            IndentationLevel(textBlock: block, indentationPoints: 0)
        }
    }
}