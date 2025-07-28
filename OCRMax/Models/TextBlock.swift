//
//  TextBlock.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
import CoreGraphics

struct TextBlock: Equatable, Codable {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let pageIndex: Int
    
    var centerX: CGFloat { boundingBox.midX }
    var centerY: CGFloat { boundingBox.midY }
    var minX: CGFloat { boundingBox.minX }
    var maxX: CGFloat { boundingBox.maxX }
    var minY: CGFloat { boundingBox.minY }
    var maxY: CGFloat { boundingBox.maxY }
    var width: CGFloat { boundingBox.width }
    var height: CGFloat { boundingBox.height }
    
    init(text: String, boundingBox: CGRect, confidence: Float, pageIndex: Int = 0) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.pageIndex = pageIndex
    }
    
    func isInSameRow(as other: TextBlock, tolerance: CGFloat = 0.1) -> Bool {
        let verticalOverlap = min(maxY, other.maxY) - max(minY, other.minY)
        let averageHeight = (height + other.height) / 2
        return verticalOverlap > averageHeight * tolerance
    }
    
    func isInSameColumn(as other: TextBlock, tolerance: CGFloat = 0.1) -> Bool {
        let horizontalOverlap = min(maxX, other.maxX) - max(minX, other.minX)
        let averageWidth = (width + other.width) / 2
        return horizontalOverlap > averageWidth * tolerance
    }
    
    func horizontalDistanceTo(_ other: TextBlock) -> CGFloat {
        if maxX <= other.minX {
            return other.minX - maxX
        } else if other.maxX <= minX {
            return minX - other.maxX
        } else {
            return 0
        }
    }
    
    func verticalDistanceTo(_ other: TextBlock) -> CGFloat {
        if maxY <= other.minY {
            return other.minY - maxY
        } else if other.maxY <= minY {
            return minY - other.maxY
        } else {
            return 0
        }
    }
}

extension TextBlock {
    static func sortedByPosition(_ blocks: [TextBlock]) -> [TextBlock] {
        return blocks.sorted { first, second in
            if abs(first.centerY - second.centerY) < 0.05 {
                return first.centerX < second.centerX
            }
            return first.centerY < second.centerY
        }
    }
    
    static func groupByRows(_ blocks: [TextBlock], tolerance: CGFloat = 0.1) -> [[TextBlock]] {
        let sortedBlocks = blocks.sorted { $0.centerY < $1.centerY }
        var rows: [[TextBlock]] = []
        var currentRow: [TextBlock] = []
        
        for block in sortedBlocks {
            if let lastBlock = currentRow.last,
               !block.isInSameRow(as: lastBlock, tolerance: tolerance) {
                if !currentRow.isEmpty {
                    rows.append(currentRow.sorted { $0.centerX < $1.centerX })
                }
                currentRow = [block]
            } else {
                currentRow.append(block)
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow.sorted { $0.centerX < $1.centerX })
        }
        
        return rows
    }
}