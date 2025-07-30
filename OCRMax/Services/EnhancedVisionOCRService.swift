//
//  EnhancedVisionOCRService.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
import Vision
import UIKit

final class EnhancedVisionOCRService: EnhancedOCRServiceProtocol {
    
    private let visionService: VisionOCRService
    private let imageEnhancer: DocumentImageEnhancer
    private let payslipProcessor: PayslipImageProcessor
    private let payslipDetector: PayslipTableDetector
    private let tableParser: TableParserService
    private let templateEngine: PayslipTemplateEngine
    private let fieldExtractor: PayslipFieldExtractor
    
    init(configuration: VNRecognizeTextRequestConfiguration = EnhancedVisionOCRService.defaultConfiguration()) {
        self.visionService = VisionOCRService(configuration: configuration)
        self.imageEnhancer = DocumentImageEnhancer()
        self.payslipProcessor = PayslipImageProcessor(documentEnhancer: imageEnhancer)
        self.tableParser = TableParserService()
        self.templateEngine = PayslipTemplateEngine()
        self.fieldExtractor = PayslipFieldExtractor(templateEngine: templateEngine)
        self.payslipDetector = PayslipTableDetector(
            payslipProcessor: payslipProcessor,
            tableParser: tableParser
        )
    }
    
    // MARK: - Enhanced OCR Methods
    
    func recognizeTextBlocks(from image: UIImage) async throws -> [TextBlock] {
        // Step 1: Enhance image for better OCR
        let enhancedImage = try await imageEnhancer.enhanceImage(image)
        
        guard let cgImage = enhancedImage.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.processingFailed)
                    return
                }
                
                let textBlocks = self.convertObservationsToTextBlocks(observations, pageIndex: 0)
                
                if textBlocks.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: textBlocks)
                }
            }
            
            self.configureRequest(request)
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func recognizeTextBlocks(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> [TextBlock] {
        var allTextBlocks: [TextBlock] = []
        let totalImages = images.count
        
        // First enhance all images
        progressHandler("Enhancing images for better OCR...")
        let enhancedImages = try await imageEnhancer.enhanceImages(images) { progress in
            progressHandler("Image enhancement: \(progress)")
        }
        
        for (index, image) in enhancedImages.enumerated() {
            progressHandler("Processing page \(index + 1) of \(totalImages)...")
            
            do {
                let pageTextBlocks = try await recognizeTextBlocksFromEnhanced(image: image)
                let updatedBlocks = pageTextBlocks.map { block in
                    TextBlock(
                        text: block.text,
                        boundingBox: block.boundingBox,
                        confidence: block.confidence,
                        pageIndex: index
                    )
                }
                allTextBlocks.append(contentsOf: updatedBlocks)
            } catch OCRError.invalidImage {
                progressHandler("Warning: Invalid image at page \(index + 1), skipping...")
                continue
            } catch OCRError.noTextFound {
                progressHandler("Warning: No text found on page \(index + 1)")
                continue
            } catch {
                progressHandler("Warning: Failed to process page \(index + 1): \(error.localizedDescription)")
                continue
            }
        }
        
        progressHandler("OCR processing completed")
        
        if allTextBlocks.isEmpty {
            throw OCRError.noTextFound
        }
        
        return allTextBlocks
    }
    
    // MARK: - Backward Compatibility (OCRServiceProtocol)
    
    func recognizeText(from image: UIImage) async throws -> String {
        let textBlocks = try await recognizeTextBlocks(from: image)
        return convertTextBlocksToString(textBlocks)
    }
    
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String {
        let textBlocks = try await recognizeTextBlocks(from: images, progressHandler: progressHandler)
        return convertTextBlocksToString(textBlocks, includePageMarkers: true)
    }
    
    func setLanguage(_ language: String) {
        visionService.setLanguage(language)
    }
    
    func getSupportedLanguages() -> [String] {
        return visionService.getSupportedLanguages()
    }
    
    // MARK: - Private Methods
    
    private func convertObservationsToTextBlocks(_ observations: [VNRecognizedTextObservation], pageIndex: Int) -> [TextBlock] {
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            
            let normalizedBoundingBox = observation.boundingBox
            let confidence = candidate.confidence
            let text = candidate.string
            
            // Convert normalized coordinates (0-1) to actual coordinates
            let boundingBox = CGRect(
                x: normalizedBoundingBox.origin.x,
                y: 1.0 - normalizedBoundingBox.origin.y - normalizedBoundingBox.height, // Flip Y coordinate
                width: normalizedBoundingBox.width,
                height: normalizedBoundingBox.height
            )
            
            return TextBlock(
                text: text,
                boundingBox: boundingBox,
                confidence: confidence,
                pageIndex: pageIndex
            )
        }
    }
    
    private func convertTextBlocksToString(_ textBlocks: [TextBlock], includePageMarkers: Bool = false) -> String {
        if !includePageMarkers {
            let sortedBlocks = TextBlock.sortedByPosition(textBlocks)
            return sortedBlocks.map { $0.text }.joined(separator: "\n")
        }
        
        // Group by page and add page markers
        let pageGroups = Dictionary(grouping: textBlocks) { $0.pageIndex }
        var result = ""
        
        for pageIndex in pageGroups.keys.sorted() {
            guard let blocks = pageGroups[pageIndex] else { continue }
            
            if !result.isEmpty {
                result += "\n\n"
            }
            
            result += "--- Page \(pageIndex + 1) ---\n"
            let sortedBlocks = TextBlock.sortedByPosition(blocks)
            result += sortedBlocks.map { $0.text }.joined(separator: "\n")
        }
        
        return result
    }
    
    private func configureRequest(_ request: VNRecognizeTextRequest) {
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
    }
    
    // MARK: - Payslip-Specific OCR Methods
    
    func recognizePayslipTextBlocks(from image: UIImage) async throws -> ([TextBlock], PayslipTableStructure) {
        // Step 1: Process image specifically for payslip structure
        let processedImage = try await payslipProcessor.processPayslipImage(image)
        
        // Step 2: Detect table structure
        let tableStructure = try await payslipProcessor.detectTableStructure(in: processedImage)
        
        // Step 3: Perform OCR on the processed image
        let textBlocks = try await recognizeTextBlocksFromEnhanced(image: processedImage)
        
        return (textBlocks, tableStructure)
    }
    
    func recognizePayslipWithAdvancedAnalysis(from image: UIImage) async throws -> PayslipRecognitionResult {
        // Step 1: Enhance and process the image
        let enhancedImage = try await imageEnhancer.enhanceImage(image)
        
        // Step 2: Perform OCR to get text blocks
        let textBlocks = try await recognizeTextBlocksFromEnhanced(image: enhancedImage)
        
        // Step 3: Detect comprehensive payslip structure
        let structureAnalysis = try await payslipDetector.detectPayslipStructure(in: enhancedImage, textBlocks: textBlocks)
        
        // Step 4: Validate payslip format
        let validationResult = payslipDetector.validatePayslipFormat(analysis: structureAnalysis)
        
        // Step 5: Generate structured table data
        let tableData = tableParser.generateTableData(from: structureAnalysis.parsedTable)
        
        return PayslipRecognitionResult(
            textBlocks: textBlocks,
            structureAnalysis: structureAnalysis,
            validationResult: validationResult,
            tableData: tableData,
            overallConfidence: calculateOverallConfidence(
                structureAnalysis: structureAnalysis,
                validationResult: validationResult
            )
        )
    }
    
    func recognizeMilitaryPayslip(from image: UIImage) async throws -> MilitaryPayslipRecognitionResult {
        // Step 1: Enhance and process the image
        let enhancedImage = try await imageEnhancer.enhanceImage(image)
        
        // Step 2: Perform OCR to get text blocks
        let textBlocks = try await recognizeTextBlocksFromEnhanced(image: enhancedImage)
        
        // Step 3: Detect comprehensive payslip structure
        let structureAnalysis = try await payslipDetector.detectPayslipStructure(in: enhancedImage, textBlocks: textBlocks)
        
        // Step 4: Identify the best matching template
        let template = try await templateEngine.identifyPayslipTemplate(from: structureAnalysis)
        
        // Step 5: Extract structured military payslip data
        let militaryPayslip = try await fieldExtractor.extractMilitaryPayslip(from: structureAnalysis, using: template)
        
        // Step 6: Validate payslip format
        let validationResult = payslipDetector.validatePayslipFormat(analysis: structureAnalysis)
        
        // Step 7: Generate structured table data
        let tableData = tableParser.generateTableData(from: structureAnalysis.parsedTable)
        
        return MilitaryPayslipRecognitionResult(
            militaryPayslip: militaryPayslip,
            template: template,
            textBlocks: textBlocks,
            structureAnalysis: structureAnalysis,
            validationResult: validationResult,
            tableData: tableData,
            processingMetadata: ProcessingMetadata(
                imageEnhancementTime: 0, // Could be tracked if needed
                ocrProcessingTime: 0,    // Could be tracked if needed
                structureAnalysisTime: 0, // Could be tracked if needed
                fieldExtractionTime: militaryPayslip.extractionMetadata.processingTime,
                totalProcessingTime: militaryPayslip.extractionMetadata.processingTime,
                templateMatchConfidence: structureAnalysis.confidence,
                overallSuccess: validationResult.isValid && militaryPayslip.confidence >= 0.7
            )
        )
    }
    
    static func payslipOptimizedConfiguration() -> VNRecognizeTextRequestConfiguration {
        var config = VNRecognizeTextRequestConfiguration()
        config.recognitionLevel = .accurate
        config.recognitionLanguages = ["en-US", "en-IN"]
        config.usesLanguageCorrection = true
        return config
    }
    
    // MARK: - Private Helper Methods
    
    private func recognizeTextBlocksFromEnhanced(image: UIImage) async throws -> [TextBlock] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.processingFailed)
                    return
                }
                
                let textBlocks = self.convertObservationsToTextBlocks(observations, pageIndex: 0)
                
                if textBlocks.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: textBlocks)
                }
            }
            
            self.configureRequest(request)
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func calculateOverallConfidence(structureAnalysis: PayslipStructureAnalysis, validationResult: PayslipValidationResult) -> Float {
        return (structureAnalysis.confidence + validationResult.score) / 2
    }
    
    private static func defaultConfiguration() -> VNRecognizeTextRequestConfiguration {
        var config = VNRecognizeTextRequestConfiguration()
        config.recognitionLevel = .accurate
        config.recognitionLanguages = ["en-US"]
        config.usesLanguageCorrection = true
        return config
    }
}

// MARK: - Enhanced Recognition Result

struct PayslipRecognitionResult {
    let textBlocks: [TextBlock]
    let structureAnalysis: PayslipStructureAnalysis
    let validationResult: PayslipValidationResult
    let tableData: TableData
    let overallConfidence: Float
}

struct MilitaryPayslipRecognitionResult {
    let militaryPayslip: MilitaryPayslip
    let template: PayslipTemplate
    let textBlocks: [TextBlock]
    let structureAnalysis: PayslipStructureAnalysis
    let validationResult: PayslipValidationResult
    let tableData: TableData
    let processingMetadata: ProcessingMetadata
}

struct ProcessingMetadata {
    let imageEnhancementTime: TimeInterval
    let ocrProcessingTime: TimeInterval
    let structureAnalysisTime: TimeInterval
    let fieldExtractionTime: TimeInterval
    let totalProcessingTime: TimeInterval
    let templateMatchConfidence: Float
    let overallSuccess: Bool
}