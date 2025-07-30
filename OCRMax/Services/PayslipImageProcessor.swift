//
//  PayslipImageProcessor.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import UIKit
import CoreImage
import Vision

protocol PayslipImageProcessorProtocol {
    func processPayslipImage(_ image: UIImage) async throws -> UIImage
    func detectTableStructure(in image: UIImage) async throws -> PayslipTableStructure
}

final class PayslipImageProcessor: PayslipImageProcessorProtocol {
    
    private let context = CIContext()
    private let documentEnhancer: DocumentImageEnhancer
    
    init(documentEnhancer: DocumentImageEnhancer = DocumentImageEnhancer()) {
        self.documentEnhancer = documentEnhancer
    }
    
    enum ProcessingError: LocalizedError {
        case invalidImage
        case tableDetectionFailed
        case enhancementFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid payslip image provided"
            case .tableDetectionFailed:
                return "Failed to detect table structure in payslip"
            case .enhancementFailed:
                return "Failed to enhance payslip image"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func processPayslipImage(_ image: UIImage) async throws -> UIImage {
        // Step 1: Basic document enhancement
        let enhancedImage = try await documentEnhancer.enhanceImage(image)
        
        // Step 2: Payslip-specific processing
        guard let ciImage = CIImage(image: enhancedImage) else {
            throw ProcessingError.invalidImage
        }
        
        var processedImage = ciImage
        
        // Step 3: Table border enhancement
        processedImage = enhanceTableBorders(processedImage)
        
        // Step 4: Grid line strengthening
        processedImage = strengthenGridLines(processedImage)
        
        // Step 5: Header/footer region optimization
        processedImage = optimizeHeaderFooterRegions(processedImage)
        
        // Step 6: Column separator enhancement
        processedImage = enhanceColumnSeparators(processedImage)
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            throw ProcessingError.enhancementFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func detectTableStructure(in image: UIImage) async throws -> PayslipTableStructure {
        let processedImage = try await processPayslipImage(image)
        
        guard let ciImage = CIImage(image: processedImage) else {
            throw ProcessingError.invalidImage
        }
        
        // Detect horizontal and vertical lines
        let horizontalLines = try await detectHorizontalLines(in: ciImage)
        let verticalLines = try await detectVerticalLines(in: ciImage)
        
        // Identify header region
        let headerRegion = identifyHeaderRegion(horizontalLines: horizontalLines, imageHeight: ciImage.extent.height)
        
        // Detect table cells
        let tableCells = generateTableCells(
            horizontalLines: horizontalLines,
            verticalLines: verticalLines,
            imageSize: ciImage.extent.size
        )
        
        return PayslipTableStructure(
            horizontalLines: horizontalLines,
            verticalLines: verticalLines,
            headerRegion: headerRegion,
            tableCells: tableCells,
            imageSize: ciImage.extent.size
        )
    }
    
    // MARK: - Private Enhancement Methods
    
    private func enhanceTableBorders(_ image: CIImage) -> CIImage {
        // Apply edge detection to enhance table borders
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return image
        }
        
        edgeFilter.setValue(image, forKey: kCIInputImageKey)
        edgeFilter.setValue(2.0, forKey: kCIInputIntensityKey)
        
        guard let edges = edgeFilter.outputImage else {
            return image
        }
        
        // Combine original with enhanced edges
        guard let additionFilter = CIFilter(name: "CIAdditionCompositing") else {
            return image
        }
        
        additionFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        additionFilter.setValue(edges, forKey: kCIInputImageKey)
        
        return additionFilter.outputImage ?? image
    }
    
    private func strengthenGridLines(_ image: CIImage) -> CIImage {
        // Apply morphological operations to strengthen grid lines
        
        // Horizontal line detection kernel
        let horizontalKernel = CIFilter(name: "CIMorphologyRectangleMaximum")
        horizontalKernel?.setValue(image, forKey: kCIInputImageKey)
        horizontalKernel?.setValue(15, forKey: "inputWidth")
        horizontalKernel?.setValue(1, forKey: "inputHeight")
        
        // Vertical line detection kernel
        let verticalKernel = CIFilter(name: "CIMorphologyRectangleMaximum")
        verticalKernel?.setValue(image, forKey: kCIInputImageKey)
        verticalKernel?.setValue(1, forKey: "inputWidth")
        verticalKernel?.setValue(15, forKey: "inputHeight")
        
        guard let horizontal = horizontalKernel?.outputImage,
              let vertical = verticalKernel?.outputImage else {
            return image
        }
        
        // Combine horizontal and vertical line enhancements
        guard let combineFilter = CIFilter(name: "CIMaximumCompositing") else {
            return image
        }
        
        combineFilter.setValue(horizontal, forKey: kCIInputBackgroundImageKey)
        combineFilter.setValue(vertical, forKey: kCIInputImageKey)
        
        guard let combined = combineFilter.outputImage else {
            return image
        }
        
        // Blend with original image
        guard let blendFilter = CIFilter(name: "CIOverlayBlendMode") else {
            return image
        }
        
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(combined, forKey: kCIInputImageKey)
        
        return blendFilter.outputImage ?? image
    }
    
    private func optimizeHeaderFooterRegions(_ image: CIImage) -> CIImage {
        let imageHeight = image.extent.height
        let headerHeight = imageHeight * 0.15  // Top 15% for header
        let footerHeight = imageHeight * 0.10  // Bottom 10% for footer
        
        // Create masks for header and footer regions
        let headerRect = CGRect(x: 0, y: imageHeight - headerHeight, width: image.extent.width, height: headerHeight)
        let _ = CGRect(x: 0, y: 0, width: image.extent.width, height: footerHeight) // Future footer processing
        
        // Apply stronger contrast to header region
        guard let headerCrop = CIFilter(name: "CICrop") else {
            return image
        }
        headerCrop.setValue(image, forKey: kCIInputImageKey)
        headerCrop.setValue(CIVector(cgRect: headerRect), forKey: "inputRectangle")
        
        guard let headerImage = headerCrop.outputImage else {
            return image
        }
        
        // Enhance header contrast
        guard let headerContrast = CIFilter(name: "CIColorControls") else {
            return image
        }
        headerContrast.setValue(headerImage, forKey: kCIInputImageKey)
        headerContrast.setValue(2.2, forKey: kCIInputContrastKey)
        headerContrast.setValue(0.1, forKey: kCIInputBrightnessKey)
        
        // For now, return the original image (full header/footer processing would be complex)
        return image
    }
    
    private func enhanceColumnSeparators(_ image: CIImage) -> CIImage {
        // Apply vertical line enhancement specifically for column separators
        guard let morphFilter = CIFilter(name: "CIMorphologyRectangleMaximum") else {
            return image
        }
        
        morphFilter.setValue(image, forKey: kCIInputImageKey)
        morphFilter.setValue(1, forKey: "inputWidth")      // 1 pixel wide
        morphFilter.setValue(20, forKey: "inputHeight")    // 20 pixels tall
        
        guard let verticalLines = morphFilter.outputImage else {
            return image
        }
        
        // Blend vertical lines back with original
        guard let blendFilter = CIFilter(name: "CIMultiplyBlendMode") else {
            return image
        }
        
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(verticalLines, forKey: kCIInputImageKey)
        
        return blendFilter.outputImage ?? image
    }
    
    // MARK: - Line Detection Methods
    
    private func detectHorizontalLines(in image: CIImage) async throws -> [LineSegment] {
        // Use Hough line detection or morphological operations
        return try await withCheckedThrowingContinuation { continuation in
            // Simplified line detection - in reality would use more sophisticated algorithms
            let lines = performHoughLineDetection(image: image, isHorizontal: true)
            continuation.resume(returning: lines)
        }
    }
    
    private func detectVerticalLines(in image: CIImage) async throws -> [LineSegment] {
        return try await withCheckedThrowingContinuation { continuation in
            let lines = performHoughLineDetection(image: image, isHorizontal: false)
            continuation.resume(returning: lines)
        }
    }
    
    private func performHoughLineDetection(image: CIImage, isHorizontal: Bool) -> [LineSegment] {
        // Simplified line detection implementation
        // In a real implementation, you would use OpenCV or custom Hough transform
        
        let imageSize = image.extent.size
        var lines: [LineSegment] = []
        
        if isHorizontal {
            // Generate some sample horizontal lines for testing
            for i in stride(from: 0, to: imageSize.height, by: imageSize.height / 10) {
                let line = LineSegment(
                    start: CGPoint(x: 0, y: i),
                    end: CGPoint(x: imageSize.width, y: i),
                    strength: 0.8
                )
                lines.append(line)
            }
        } else {
            // Generate some sample vertical lines for testing
            for i in stride(from: 0, to: imageSize.width, by: imageSize.width / 5) {
                let line = LineSegment(
                    start: CGPoint(x: i, y: 0),
                    end: CGPoint(x: i, y: imageSize.height),
                    strength: 0.7
                )
                lines.append(line)
            }
        }
        
        return lines
    }
    
    private func identifyHeaderRegion(horizontalLines: [LineSegment], imageHeight: CGFloat) -> CGRect {
        // Find the first strong horizontal line to determine header boundary
        let sortedLines = horizontalLines.sorted { $0.start.y > $1.start.y } // Top to bottom
        
        for line in sortedLines {
            if line.strength > 0.7 && line.start.y > imageHeight * 0.1 {
                // Header region is from top to this line
                return CGRect(x: 0, y: line.start.y, width: line.end.x - line.start.x, height: imageHeight - line.start.y)
            }
        }
        
        // Default header region (top 20%)
        return CGRect(x: 0, y: imageHeight * 0.8, width: horizontalLines.first?.end.x ?? 0, height: imageHeight * 0.2)
    }
    
    private func generateTableCells(horizontalLines: [LineSegment], verticalLines: [LineSegment], imageSize: CGSize) -> [TableCell] {
        var cells: [TableCell] = []
        
        // Sort lines
        let sortedHorizontal = horizontalLines.sorted { $0.start.y > $1.start.y }
        let sortedVertical = verticalLines.sorted { $0.start.x < $1.start.x }
        
        // Generate cells from line intersections
        for i in 0..<(sortedHorizontal.count - 1) {
            for j in 0..<(sortedVertical.count - 1) {
                let topLine = sortedHorizontal[i]
                let bottomLine = sortedHorizontal[i + 1]
                let leftLine = sortedVertical[j]
                let rightLine = sortedVertical[j + 1]
                
                let cellRect = CGRect(
                    x: leftLine.start.x,
                    y: bottomLine.start.y,
                    width: rightLine.start.x - leftLine.start.x,
                    height: topLine.start.y - bottomLine.start.y
                )
                
                let cell = TableCell(
                    bounds: cellRect,
                    row: i,
                    column: j,
                    confidence: (topLine.strength + bottomLine.strength + leftLine.strength + rightLine.strength) / 4
                )
                
                cells.append(cell)
            }
        }
        
        return cells
    }
}

// MARK: - Supporting Data Structures

struct PayslipTableStructure {
    let horizontalLines: [LineSegment]
    let verticalLines: [LineSegment]
    let headerRegion: CGRect
    let tableCells: [TableCell]
    let imageSize: CGSize
}

struct LineSegment {
    let start: CGPoint
    let end: CGPoint
    let strength: Float  // Confidence/intensity of the line
    
    var length: CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
    
    var isHorizontal: Bool {
        return abs(end.y - start.y) < abs(end.x - start.x)
    }
}

struct TableCell {
    let bounds: CGRect
    let row: Int
    let column: Int
    let confidence: Float
    
    var center: CGPoint {
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    var area: CGFloat {
        return bounds.width * bounds.height
    }
} 