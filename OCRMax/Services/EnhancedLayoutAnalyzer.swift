//
//  EnhancedLayoutAnalyzer.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import CoreGraphics

protocol EnhancedLayoutAnalyzerProtocol: LayoutAnalyzerProtocol {
    func analyzeTableStructure(from textBlocks: [TextBlock], tableStructure: PayslipTableStructure?) -> EnhancedLayoutAnalysis
    func detectTableCells(from textBlocks: [TextBlock], tableStructure: PayslipTableStructure) -> [TableCellAnalysis]
    func classifyTableRegions(from textBlocks: [TextBlock], tableStructure: PayslipTableStructure) -> [TableRegion]
}

final class EnhancedLayoutAnalyzer: EnhancedLayoutAnalyzerProtocol {
    
    private let basicLayoutAnalyzer: LayoutAnalyzer
    private let tableDetectionThreshold: CGFloat = 0.7
    private let cellOverlapThreshold: CGFloat = 0.5
    private let headerRegionThreshold: CGFloat = 0.8
    
    init(basicLayoutAnalyzer: LayoutAnalyzer = LayoutAnalyzer()) {
        self.basicLayoutAnalyzer = basicLayoutAnalyzer
    }
    
    // MARK: - Enhanced Analysis Methods
    
    func analyzeTableStructure(from textBlocks: [TextBlock], tableStructure: PayslipTableStructure?) -> EnhancedLayoutAnalysis {
        // First get the basic layout analysis
        let basicAnalysis = basicLayoutAnalyzer.analyzeLayout(from: textBlocks)
        
        guard let tableStructure = tableStructure else {
            // Return enhanced analysis without table-specific data
            return EnhancedLayoutAnalysis(
                basicAnalysis: basicAnalysis,
                tableCells: [],
                tableRegions: [],
                gridStructure: nil,
                confidence: 0.0
            )
        }
        
        // Perform enhanced table-specific analysis
        let tableCells = detectTableCells(from: textBlocks, tableStructure: tableStructure)
        let tableRegions = classifyTableRegions(from: textBlocks, tableStructure: tableStructure)
        let gridStructure = analyzeGridStructure(tableStructure: tableStructure, tableCells: tableCells)
        let confidence = calculateAnalysisConfidence(tableCells: tableCells, tableRegions: tableRegions)
        
        return EnhancedLayoutAnalysis(
            basicAnalysis: basicAnalysis,
            tableCells: tableCells,
            tableRegions: tableRegions,
            gridStructure: gridStructure,
            confidence: confidence
        )
    }
    
    func detectTableCells(from textBlocks: [TextBlock], tableStructure: PayslipTableStructure) -> [TableCellAnalysis] {
        var cellAnalyses: [TableCellAnalysis] = []
        
        for tableCell in tableStructure.tableCells {
            // Find text blocks that overlap with this cell
            let overlappingBlocks = findOverlappingTextBlocks(
                textBlocks: textBlocks,
                cellBounds: tableCell.bounds,
                threshold: cellOverlapThreshold
            )
            
            // Analyze the content type
            let contentType = classifyCellContent(textBlocks: overlappingBlocks)
            
            // Calculate reading order within the cell
            let sortedBlocks = TextBlock.sortedByPosition(overlappingBlocks)
            
            // Create cell analysis
            let cellAnalysis = TableCellAnalysis(
                cell: tableCell,
                textBlocks: sortedBlocks,
                contentType: contentType,
                isEmpty: overlappingBlocks.isEmpty,
                confidence: calculateCellConfidence(cell: tableCell, textBlocks: overlappingBlocks)
            )
            
            cellAnalyses.append(cellAnalysis)
        }
        
        return cellAnalyses
    }
    
    func classifyTableRegions(from textBlocks: [TextBlock], tableStructure: PayslipTableStructure) -> [TableRegion] {
        var regions: [TableRegion] = []
        
        // Classify header region
        let headerBlocks = findTextBlocksInRegion(textBlocks: textBlocks, region: tableStructure.headerRegion)
        if !headerBlocks.isEmpty {
            let headerRegion = TableRegion(
                bounds: tableStructure.headerRegion,
                type: .header,
                textBlocks: headerBlocks,
                confidence: calculateRegionConfidence(blocks: headerBlocks, regionType: .header)
            )
            regions.append(headerRegion)
        }
        
        // Classify data regions based on grid structure
        let dataRegions = identifyDataRegions(
            textBlocks: textBlocks,
            tableStructure: tableStructure,
            excludingHeader: tableStructure.headerRegion
        )
        regions.append(contentsOf: dataRegions)
        
        return regions
    }
    
    // MARK: - Private Analysis Methods
    
    private func findOverlappingTextBlocks(textBlocks: [TextBlock], cellBounds: CGRect, threshold: CGFloat) -> [TextBlock] {
        return textBlocks.filter { textBlock in
            let intersection = cellBounds.intersection(textBlock.boundingBox)
            let overlapArea = intersection.width * intersection.height
            let textBlockArea = textBlock.boundingBox.width * textBlock.boundingBox.height
            
            guard textBlockArea > 0 else { return false }
            
            let overlapRatio = overlapArea / textBlockArea
            return overlapRatio >= threshold
        }
    }
    
    private func classifyCellContent(textBlocks: [TextBlock]) -> CellContentType {
        guard !textBlocks.isEmpty else { return .empty }
        
        let combinedText = textBlocks.map { $0.text }.joined(separator: " ")
        
        // Check for numerical content (amounts, dates, IDs)
        if isNumericalContent(combinedText) {
            return .numerical
        }
        
        // Check for labels/headers
        if isLabelContent(combinedText) {
            return .label
        }
        
        // Check for dates
        if isDateContent(combinedText) {
            return .date
        }
        
        // Default to text
        return .text
    }
    
    private func isNumericalContent(_ text: String) -> Bool {
        let numericalPattern = #"^\s*[\d,\.\-\+\₹\$\s]+\s*$"#
        return text.range(of: numericalPattern, options: .regularExpression) != nil
    }
    
    private func isLabelContent(_ text: String) -> Bool {
        // Check if text is all uppercase or contains common label patterns
        let upperCaseRatio = Double(text.filter { $0.isUppercase }.count) / Double(text.count)
        return upperCaseRatio > 0.7 || text.contains(":") || text.hasSuffix(":")
    }
    
    private func isDateContent(_ text: String) -> Bool {
        let datePattern = #"\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}"#
        return text.range(of: datePattern, options: .regularExpression) != nil
    }
    
    private func calculateCellConfidence(cell: TableCell, textBlocks: [TextBlock]) -> Float {
        var confidence = cell.confidence
        
        // Boost confidence if cell contains text
        if !textBlocks.isEmpty {
            confidence += 0.2
        }
        
        // Boost confidence for well-formed cells (reasonable aspect ratio)
        let aspectRatio = cell.bounds.width / cell.bounds.height
        if aspectRatio > 0.5 && aspectRatio < 5.0 {
            confidence += 0.1
        }
        
        // Ensure confidence doesn't exceed 1.0
        return min(confidence, 1.0)
    }
    
    private func findTextBlocksInRegion(textBlocks: [TextBlock], region: CGRect) -> [TextBlock] {
        return textBlocks.filter { textBlock in
            region.intersects(textBlock.boundingBox)
        }
    }
    
    private func calculateRegionConfidence(blocks: [TextBlock], regionType: TableRegionType) -> Float {
        guard !blocks.isEmpty else { return 0.0 }
        
        let averageConfidence = blocks.reduce(0) { $0 + $1.confidence } / Float(blocks.count)
        
        // Adjust confidence based on region type characteristics
        switch regionType {
        case .header:
            // Headers often have larger, bolder text
            return min(averageConfidence + 0.1, 1.0)
        case .data:
            return averageConfidence
        case .footer:
            return min(averageConfidence + 0.05, 1.0)
        }
    }
    
    private func identifyDataRegions(textBlocks: [TextBlock], tableStructure: PayslipTableStructure, excludingHeader: CGRect) -> [TableRegion] {
        var dataRegions: [TableRegion] = []
        
        // Group table cells by rows (excluding header region)
        let dataCells = tableStructure.tableCells.filter { !excludingHeader.intersects($0.bounds) }
        let cellsByRow = Dictionary(grouping: dataCells) { $0.row }
        
        for (_, rowCells) in cellsByRow {
            guard !rowCells.isEmpty else { continue }
            
            // Calculate bounding box for this row
            let minX = rowCells.map { $0.bounds.minX }.min() ?? 0
            let maxX = rowCells.map { $0.bounds.maxX }.max() ?? 0
            let minY = rowCells.map { $0.bounds.minY }.min() ?? 0
            let maxY = rowCells.map { $0.bounds.maxY }.max() ?? 0
            
            let rowBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            // Find text blocks in this row
            let rowTextBlocks = findTextBlocksInRegion(textBlocks: textBlocks, region: rowBounds)
            
            if !rowTextBlocks.isEmpty {
                let dataRegion = TableRegion(
                    bounds: rowBounds,
                    type: .data,
                    textBlocks: rowTextBlocks,
                    confidence: calculateRegionConfidence(blocks: rowTextBlocks, regionType: .data)
                )
                dataRegions.append(dataRegion)
            }
        }
        
        return dataRegions
    }
    
    private func analyzeGridStructure(tableStructure: PayslipTableStructure, tableCells: [TableCellAnalysis]) -> GridStructure? {
        guard !tableCells.isEmpty else { return nil }
        
        // Calculate grid dimensions
        let maxRow = tableCells.map { $0.cell.row }.max() ?? 0
        let maxColumn = tableCells.map { $0.cell.column }.max() ?? 0
        
        let gridDimensions = GridDimensions(rows: maxRow + 1, columns: maxColumn + 1)
        
        // Analyze column types
        let columnTypes = analyzeColumnTypes(tableCells: tableCells, columnCount: gridDimensions.columns)
        
        // Calculate uniformity metrics
        let uniformity = calculateGridUniformity(tableCells: tableCells)
        
        return GridStructure(
            dimensions: gridDimensions,
            columnTypes: columnTypes,
            uniformity: uniformity,
            hasHeader: !tableStructure.headerRegion.isEmpty
        )
    }
    
    private func analyzeColumnTypes(tableCells: [TableCellAnalysis], columnCount: Int) -> [ColumnType] {
        var columnTypes: [ColumnType] = []
        
        for column in 0..<columnCount {
            let columnCells = tableCells.filter { $0.cell.column == column }
            let contentTypes = columnCells.map { $0.contentType }
            
            // Determine predominant content type for this column
            let columnType = determinePredominantColumnType(contentTypes: contentTypes)
            columnTypes.append(columnType)
        }
        
        return columnTypes
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
    
    private func calculateGridUniformity(tableCells: [TableCellAnalysis]) -> Float {
        guard tableCells.count > 1 else { return 1.0 }
        
        // Calculate variance in cell sizes
        let cellAreas = tableCells.map { $0.cell.area }
        let averageArea = cellAreas.reduce(0, +) / CGFloat(cellAreas.count)
        
        let variance = cellAreas.reduce(0) { result, area in
            result + pow(area - averageArea, 2)
        } / CGFloat(cellAreas.count)
        
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = standardDeviation / averageArea
        
        // Convert to uniformity score (lower variation = higher uniformity)
        return max(0.0, 1.0 - Float(coefficientOfVariation))
    }
    
    private func calculateAnalysisConfidence(tableCells: [TableCellAnalysis], tableRegions: [TableRegion]) -> Float {
        guard !tableCells.isEmpty && !tableRegions.isEmpty else { return 0.0 }
        
        let cellConfidences = tableCells.map { $0.confidence }
        let regionConfidences = tableRegions.map { $0.confidence }
        
        let averageCellConfidence = cellConfidences.reduce(0, +) / Float(cellConfidences.count)
        let averageRegionConfidence = regionConfidences.reduce(0, +) / Float(regionConfidences.count)
        
        // Weight cell confidence more heavily
        return (averageCellConfidence * 0.7) + (averageRegionConfidence * 0.3)
    }
    
    // MARK: - LayoutAnalyzerProtocol Implementation
    
    func analyzeLayout(from textBlocks: [TextBlock]) -> LayoutAnalysis {
        return basicLayoutAnalyzer.analyzeLayout(from: textBlocks)
    }
    
    func detectColumns(in textBlocks: [TextBlock]) -> [ColumnGroup] {
        return basicLayoutAnalyzer.detectColumns(in: textBlocks)
    }
    
    func calculateSpacing(between textBlocks: [TextBlock]) -> SpacingInfo {
        return basicLayoutAnalyzer.calculateSpacing(between: textBlocks)
    }
    
    func groupTextBlocks(_ textBlocks: [TextBlock]) -> [TextGroup] {
        return basicLayoutAnalyzer.groupTextBlocks(textBlocks)
    }
}

// MARK: - Enhanced Data Structures

struct EnhancedLayoutAnalysis {
    let basicAnalysis: LayoutAnalysis
    let tableCells: [TableCellAnalysis]
    let tableRegions: [TableRegion]
    let gridStructure: GridStructure?
    let confidence: Float
}

struct TableCellAnalysis {
    let cell: TableCell
    let textBlocks: [TextBlock]
    let contentType: CellContentType
    let isEmpty: Bool
    let confidence: Float
}

struct TableRegion {
    let bounds: CGRect
    let type: TableRegionType
    let textBlocks: [TextBlock]
    let confidence: Float
}

struct GridStructure {
    let dimensions: GridDimensions
    let columnTypes: [ColumnType]
    let uniformity: Float  // 0.0 to 1.0, higher is more uniform
    let hasHeader: Bool
}

struct GridDimensions {
    let rows: Int
    let columns: Int
}

enum CellContentType {
    case label      // Text labels, headers
    case numerical  // Numbers, amounts, quantities
    case date       // Date values
    case text       // General text content
    case empty      // No content
}

enum TableRegionType {
    case header
    case data
    case footer
}

enum ColumnType {
    case label      // Contains mainly labels
    case numerical  // Contains mainly numbers
    case date       // Contains mainly dates
    case text       // Contains mainly text
    case mixed      // Mixed content types
} 