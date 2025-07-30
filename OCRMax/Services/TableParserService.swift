//
//  TableParserService.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import CoreGraphics

protocol TableParserServiceProtocol {
    func parseTable(textBlocks: [TextBlock], tableStructure: PayslipTableStructure) async throws -> ParsedTable
    func extractCellRelationships(from tableCells: [TableCellAnalysis]) -> [CellRelationship]
    func generateTableData(from parsedTable: ParsedTable) -> TableData
}

final class TableParserService: TableParserServiceProtocol {
    
    private let enhancedLayoutAnalyzer: EnhancedLayoutAnalyzer
    
    init(enhancedLayoutAnalyzer: EnhancedLayoutAnalyzer = EnhancedLayoutAnalyzer()) {
        self.enhancedLayoutAnalyzer = enhancedLayoutAnalyzer
    }
    
    enum ParsingError: LocalizedError {
        case invalidTableStructure
        case noDataFound
        case parsingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidTableStructure:
                return "Invalid table structure provided for parsing"
            case .noDataFound:
                return "No data found in table structure"
            case .parsingFailed(let reason):
                return "Table parsing failed: \(reason)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func parseTable(textBlocks: [TextBlock], tableStructure: PayslipTableStructure) async throws -> ParsedTable {
        // Perform enhanced layout analysis
        let layoutAnalysis = enhancedLayoutAnalyzer.analyzeTableStructure(
            from: textBlocks,
            tableStructure: tableStructure
        )
        
        guard !layoutAnalysis.tableCells.isEmpty else {
            throw ParsingError.noDataFound
        }
        
        // Extract cell relationships
        let relationships = extractCellRelationships(from: layoutAnalysis.tableCells)
        
        // Generate structured rows and columns
        let rows = generateTableRows(from: layoutAnalysis.tableCells)
        let columns = generateTableColumns(from: layoutAnalysis.tableCells, gridStructure: layoutAnalysis.gridStructure)
        
        // Extract header information
        let headers = extractTableHeaders(from: layoutAnalysis.tableRegions)
        
        // Create parsed table
        return ParsedTable(
            headers: headers,
            rows: rows,
            columns: columns,
            relationships: relationships,
            gridStructure: layoutAnalysis.gridStructure,
            confidence: layoutAnalysis.confidence
        )
    }
    
    func extractCellRelationships(from tableCells: [TableCellAnalysis]) -> [CellRelationship] {
        var relationships: [CellRelationship] = []
        
        for cell in tableCells {
            // Find horizontal neighbors
            let rightNeighbor = findHorizontalNeighbor(of: cell, direction: .right, in: tableCells)
            _ = findHorizontalNeighbor(of: cell, direction: .left, in: tableCells)
            
            // Find vertical neighbors
            _ = findVerticalNeighbor(of: cell, direction: .above, in: tableCells)
            let belowNeighbor = findVerticalNeighbor(of: cell, direction: .below, in: tableCells)
            
            // Create relationships
            if let right = rightNeighbor {
                relationships.append(CellRelationship(
                    fromCell: cell.cell,
                    toCell: right.cell,
                    type: .horizontalAdjacent,
                    strength: calculateRelationshipStrength(from: cell, to: right)
                ))
            }
            
            if let below = belowNeighbor {
                relationships.append(CellRelationship(
                    fromCell: cell.cell,
                    toCell: below.cell,
                    type: .verticalAdjacent,
                    strength: calculateRelationshipStrength(from: cell, to: below)
                ))
            }
            
            // Check for label-value relationships
            if let labelValueRelationship = identifyLabelValueRelationship(cell: cell, neighbors: tableCells) {
                relationships.append(labelValueRelationship)
            }
        }
        
        return relationships
    }
    
    func generateTableData(from parsedTable: ParsedTable) -> TableData {
        var tableRows: [TableDataRow] = []
        
        for row in parsedTable.rows {
            var rowData: [String: String] = [:]
            
            // Map each cell to its column header (if available)
            for cellData in row.cells {
                let columnIndex = cellData.cell.column
                
                // Find corresponding column header
                if columnIndex < parsedTable.headers.count {
                    let header = parsedTable.headers[columnIndex]
                    let cellText = cellData.textBlocks.map { $0.text }.joined(separator: " ")
                    rowData[header.text] = cellText
                } else {
                    // Use generic column identifier
                    let cellText = cellData.textBlocks.map { $0.text }.joined(separator: " ")
                    rowData["Column_\(columnIndex)"] = cellText
                }
            }
            
            let tableRow = TableDataRow(
                index: row.index,
                data: rowData,
                confidence: row.confidence
            )
            tableRows.append(tableRow)
        }
        
        return TableData(
            headers: parsedTable.headers.map { $0.text },
            rows: tableRows,
            metadata: TableMetadata(
                totalRows: tableRows.count,
                totalColumns: parsedTable.headers.count,
                hasHeaders: !parsedTable.headers.isEmpty,
                confidence: parsedTable.confidence
            )
        )
    }
    
    // MARK: - Private Methods
    
    private func generateTableRows(from tableCells: [TableCellAnalysis]) -> [TableRow] {
        let cellsByRow = Dictionary(grouping: tableCells) { $0.cell.row }
        var tableRows: [TableRow] = []
        
        for (rowIndex, rowCells) in cellsByRow.sorted(by: { $0.key < $1.key }) {
            let sortedCells = rowCells.sorted { $0.cell.column < $1.cell.column }
            
            let rowConfidence = sortedCells.map { $0.confidence }.reduce(0, +) / Float(sortedCells.count)
            
            let tableRow = TableRow(
                index: rowIndex,
                cells: sortedCells,
                confidence: rowConfidence
            )
            tableRows.append(tableRow)
        }
        
        return tableRows
    }
    
    private func generateTableColumns(from tableCells: [TableCellAnalysis], gridStructure: GridStructure?) -> [TableColumn] {
        guard let gridStructure = gridStructure else {
            return []
        }
        
        var tableColumns: [TableColumn] = []
        
        for columnIndex in 0..<gridStructure.dimensions.columns {
            let columnCells = tableCells.filter { $0.cell.column == columnIndex }
            let sortedCells = columnCells.sorted { $0.cell.row < $1.cell.row }
            
            let columnType = columnIndex < gridStructure.columnTypes.count ? 
                gridStructure.columnTypes[columnIndex] : .mixed
            
            let columnConfidence = sortedCells.map { $0.confidence }.reduce(0, +) / Float(max(sortedCells.count, 1))
            
            let tableColumn = TableColumn(
                index: columnIndex,
                cells: sortedCells,
                type: columnType,
                confidence: columnConfidence
            )
            tableColumns.append(tableColumn)
        }
        
        return tableColumns
    }
    
    private func extractTableHeaders(from tableRegions: [TableRegion]) -> [TableHeader] {
        var headers: [TableHeader] = []
        
        // Find header region
        guard let headerRegion = tableRegions.first(where: { $0.type == .header }) else {
            return headers
        }
        
        // Sort header text blocks by position (left to right)
        let sortedHeaderBlocks = TextBlock.sortedByPosition(headerRegion.textBlocks)
        
        // Group header blocks into logical header units
        let headerGroups = groupHeaderBlocks(sortedHeaderBlocks)
        
        for (index, group) in headerGroups.enumerated() {
            let headerText = group.map { $0.text }.joined(separator: " ")
            let header = TableHeader(
                text: headerText,
                columnIndex: index,
                confidence: headerRegion.confidence
            )
            headers.append(header)
        }
        
        return headers
    }
    
    private func groupHeaderBlocks(_ blocks: [TextBlock]) -> [[TextBlock]] {
        guard !blocks.isEmpty else { return [] }
        
        var groups: [[TextBlock]] = []
        var currentGroup: [TextBlock] = [blocks[0]]
        
        for i in 1..<blocks.count {
            let currentBlock = blocks[i]
            let previousBlock = blocks[i - 1]
            
            // Check if blocks are close enough to be in the same header
            let horizontalDistance = currentBlock.minX - previousBlock.maxX
            let averageHeight = (currentBlock.height + previousBlock.height) / 2
            
            if horizontalDistance < averageHeight * 2 {
                // Blocks are close, add to current group
                currentGroup.append(currentBlock)
            } else {
                // Blocks are far apart, start new group
                groups.append(currentGroup)
                currentGroup = [currentBlock]
            }
        }
        
        // Add the last group
        groups.append(currentGroup)
        
        return groups
    }
    
    private func findHorizontalNeighbor(of cell: TableCellAnalysis, direction: HorizontalDirection, in tableCells: [TableCellAnalysis]) -> TableCellAnalysis? {
        let targetColumn = direction == .right ? cell.cell.column + 1 : cell.cell.column - 1
        
        return tableCells.first { otherCell in
            otherCell.cell.row == cell.cell.row && otherCell.cell.column == targetColumn
        }
    }
    
    private func findVerticalNeighbor(of cell: TableCellAnalysis, direction: VerticalDirection, in tableCells: [TableCellAnalysis]) -> TableCellAnalysis? {
        let targetRow = direction == .below ? cell.cell.row + 1 : cell.cell.row - 1
        
        return tableCells.first { otherCell in
            otherCell.cell.column == cell.cell.column && otherCell.cell.row == targetRow
        }
    }
    
    private func calculateRelationshipStrength(from: TableCellAnalysis, to: TableCellAnalysis) -> Float {
        // Base strength on cell confidence and alignment
        let avgConfidence = (from.confidence + to.confidence) / 2
        
        // Check alignment quality
        let alignmentScore: Float
        if abs(from.cell.bounds.minY - to.cell.bounds.minY) < 10 {
            // Well-aligned horizontally
            alignmentScore = 0.2
        } else if abs(from.cell.bounds.minX - to.cell.bounds.minX) < 10 {
            // Well-aligned vertically
            alignmentScore = 0.2
        } else {
            alignmentScore = 0.0
        }
        
        return min(avgConfidence + alignmentScore, 1.0)
    }
    
    private func identifyLabelValueRelationship(cell: TableCellAnalysis, neighbors: [TableCellAnalysis]) -> CellRelationship? {
        // Check if this cell is a label (first column, contains label-like content)
        guard cell.contentType == .label else { return nil }
        
        // Find potential value cell (usually to the right)
        if let valueCell = findHorizontalNeighbor(of: cell, direction: .right, in: neighbors),
           valueCell.contentType == .numerical || valueCell.contentType == .text {
            
            return CellRelationship(
                fromCell: cell.cell,
                toCell: valueCell.cell,
                type: .labelValue,
                strength: calculateRelationshipStrength(from: cell, to: valueCell)
            )
        }
        
        return nil
    }
}

// MARK: - Supporting Data Structures

struct ParsedTable {
    let headers: [TableHeader]
    let rows: [TableRow]
    let columns: [TableColumn]
    let relationships: [CellRelationship]
    let gridStructure: GridStructure?
    let confidence: Float
}

struct TableRow {
    let index: Int
    let cells: [TableCellAnalysis]
    let confidence: Float
}

struct TableColumn {
    let index: Int
    let cells: [TableCellAnalysis]
    let type: ColumnType
    let confidence: Float
}

struct TableHeader {
    let text: String
    let columnIndex: Int
    let confidence: Float
}

struct CellRelationship {
    let fromCell: TableCell
    let toCell: TableCell
    let type: RelationshipType
    let strength: Float
}

struct TableData {
    let headers: [String]
    let rows: [TableDataRow]
    let metadata: TableMetadata
}

struct TableDataRow {
    let index: Int
    let data: [String: String]  // Column header -> Cell value
    let confidence: Float
}

struct TableMetadata {
    let totalRows: Int
    let totalColumns: Int
    let hasHeaders: Bool
    let confidence: Float
}

enum RelationshipType {
    case horizontalAdjacent
    case verticalAdjacent
    case labelValue
    case headerData
}

enum HorizontalDirection {
    case left
    case right
}

enum VerticalDirection {
    case above
    case below
} 