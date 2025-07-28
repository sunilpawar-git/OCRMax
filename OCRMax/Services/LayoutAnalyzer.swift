//
//  LayoutAnalyzer.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
import CoreGraphics

final class LayoutAnalyzer: LayoutAnalyzerProtocol {
    
    private let columnDetectionThreshold: CGFloat = 50.0
    private let paragraphSpacingThreshold: CGFloat = 1.5
    private let headerHeightThreshold: CGFloat = 1.3
    
    func analyzeLayout(from textBlocks: [TextBlock]) -> LayoutAnalysis {
        guard !textBlocks.isEmpty else {
            return LayoutAnalysis(
                columns: [],
                spacing: SpacingInfo(averageLineSpacing: 0, averageWordSpacing: 0, paragraphSpacing: 0),
                textGroups: [],
                suggestedIndentation: []
            )
        }
        
        let columns = detectColumns(in: textBlocks)
        let spacing = calculateSpacing(between: textBlocks)
        let textGroups = groupTextBlocks(textBlocks)
        let indentation = calculateIndentation(for: textBlocks)
        
        return LayoutAnalysis(
            columns: columns,
            spacing: spacing,
            textGroups: textGroups,
            suggestedIndentation: indentation
        )
    }
    
    func detectColumns(in textBlocks: [TextBlock]) -> [ColumnGroup] {
        guard !textBlocks.isEmpty else { return [] }
        
        if textBlocks.count == 1 {
            return [ColumnGroup(
                textBlocks: textBlocks,
                boundingBox: textBlocks[0].boundingBox,
                columnIndex: 0
            )]
        }
        
        let sortedBlocks = textBlocks.sorted { $0.centerX < $1.centerX }
        var columns: [[TextBlock]] = []
        var currentColumn: [TextBlock] = []
        var lastCenterX: CGFloat = 0
        
        for block in sortedBlocks {
            if currentColumn.isEmpty || abs(block.centerX - lastCenterX) < columnDetectionThreshold {
                currentColumn.append(block)
                lastCenterX = block.centerX
            } else {
                if !currentColumn.isEmpty {
                    columns.append(currentColumn)
                }
                currentColumn = [block]
                lastCenterX = block.centerX
            }
        }
        
        if !currentColumn.isEmpty {
            columns.append(currentColumn)
        }
        
        return columns.enumerated().map { index, blocks in
            let boundingBox = calculateBoundingBox(for: blocks)
            return ColumnGroup(textBlocks: blocks, boundingBox: boundingBox, columnIndex: index)
        }
    }
    
    func calculateSpacing(between textBlocks: [TextBlock]) -> SpacingInfo {
        guard textBlocks.count > 1 else {
            return SpacingInfo(averageLineSpacing: 0, averageWordSpacing: 5, paragraphSpacing: 0)
        }
        
        let rows = TextBlock.groupByRows(textBlocks)
        var lineSpacings: [CGFloat] = []
        var wordSpacings: [CGFloat] = []
        
        for i in 0..<rows.count - 1 {
            let currentRow = rows[i]
            let nextRow = rows[i + 1]
            
            if let currentBottom = currentRow.first,
               let nextTop = nextRow.first {
                let spacing = nextTop.minY - currentBottom.maxY
                lineSpacings.append(spacing)
            }
        }
        
        for row in rows {
            for i in 0..<row.count - 1 {
                let distance = row[i].horizontalDistanceTo(row[i + 1])
                if distance > 0 {
                    wordSpacings.append(distance)
                }
            }
        }
        
        let averageLineSpacing = lineSpacings.isEmpty ? 15.0 : lineSpacings.reduce(0, +) / CGFloat(lineSpacings.count)
        let averageWordSpacing = wordSpacings.isEmpty ? 5.0 : wordSpacings.reduce(0, +) / CGFloat(wordSpacings.count)
        let paragraphSpacing = averageLineSpacing * paragraphSpacingThreshold
        
        return SpacingInfo(
            averageLineSpacing: averageLineSpacing,
            averageWordSpacing: averageWordSpacing,
            paragraphSpacing: paragraphSpacing
        )
    }
    
    func groupTextBlocks(_ textBlocks: [TextBlock]) -> [TextGroup] {
        guard !textBlocks.isEmpty else { return [] }
        
        var groups: [TextGroup] = []
        let spacing = calculateSpacing(between: textBlocks)
        let rows = TextBlock.groupByRows(textBlocks)
        
        for (index, row) in rows.enumerated() {
            let groupType = determineGroupType(for: row, at: index, spacing: spacing)
            let confidence = calculateGroupConfidence(for: row, type: groupType)
            
            groups.append(TextGroup(blocks: row, groupType: groupType, confidence: confidence))
        }
        
        return mergeConsecutiveParagraphs(groups, spacing: spacing)
    }
    
    private func determineGroupType(for blocks: [TextBlock], at rowIndex: Int, spacing: SpacingInfo) -> TextGroupType {
        guard let firstBlock = blocks.first else { return .paragraph }
        
        let text = blocks.map { $0.text }.joined(separator: " ")
        let averageHeight = blocks.reduce(0) { $0 + $1.height } / CGFloat(blocks.count)
        
        if spacing.averageLineSpacing > 0 && averageHeight > spacing.averageLineSpacing * headerHeightThreshold {
            return .header
        }
        
        if text.uppercased() == text && text.count > 3 && rowIndex == 0 {
            return .header
        }
        
        if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("*") {
            return .list
        }
        
        if blocks.count > 2 && blocks.allSatisfy({ $0.width < 100 }) {
            return .table
        }
        
        return .paragraph
    }
    
    private func calculateGroupConfidence(for blocks: [TextBlock], type: TextGroupType) -> Float {
        let averageConfidence = blocks.reduce(0) { $0 + $1.confidence } / Float(blocks.count)
        
        switch type {
        case .header:
            return min(averageConfidence + 0.1, 1.0)
        case .table:
            return averageConfidence * 0.8
        default:
            return averageConfidence
        }
    }
    
    private func mergeConsecutiveParagraphs(_ groups: [TextGroup], spacing: SpacingInfo) -> [TextGroup] {
        var mergedGroups: [TextGroup] = []
        var currentParagraphBlocks: [TextBlock] = []
        
        for group in groups {
            if group.groupType == .paragraph {
                currentParagraphBlocks.append(contentsOf: group.blocks)
            } else {
                if !currentParagraphBlocks.isEmpty {
                    let confidence = currentParagraphBlocks.reduce(0) { $0 + $1.confidence } / Float(currentParagraphBlocks.count)
                    mergedGroups.append(TextGroup(blocks: currentParagraphBlocks, groupType: .paragraph, confidence: confidence))
                    currentParagraphBlocks = []
                }
                mergedGroups.append(group)
            }
        }
        
        if !currentParagraphBlocks.isEmpty {
            let confidence = currentParagraphBlocks.reduce(0) { $0 + $1.confidence } / Float(currentParagraphBlocks.count)
            mergedGroups.append(TextGroup(blocks: currentParagraphBlocks, groupType: .paragraph, confidence: confidence))
        }
        
        return mergedGroups
    }
    
    private func calculateIndentation(for textBlocks: [TextBlock]) -> [IndentationLevel] {
        guard !textBlocks.isEmpty else { return [] }
        
        let minX = textBlocks.min { $0.minX < $1.minX }?.minX ?? 0
        
        return textBlocks.map { block in
            let indentation = max(0, block.minX - minX)
            return IndentationLevel(textBlock: block, indentationPoints: indentation)
        }
    }
    
    private func calculateBoundingBox(for blocks: [TextBlock]) -> CGRect {
        guard !blocks.isEmpty else { return .zero }
        
        let minX = blocks.min { $0.minX < $1.minX }?.minX ?? 0
        let minY = blocks.min { $0.minY < $1.minY }?.minY ?? 0
        let maxX = blocks.max { $0.maxX < $1.maxX }?.maxX ?? 0
        let maxY = blocks.max { $0.maxY < $1.maxY }?.maxY ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}