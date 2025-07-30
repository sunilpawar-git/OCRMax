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
    private let payslipValidator: PayslipValidator
    private let confidenceBooster: ConfidenceBooster
    
    init(configuration: VNRecognizeTextRequestConfiguration = EnhancedVisionOCRService.defaultConfiguration()) {
        self.visionService = VisionOCRService(configuration: configuration)
        self.imageEnhancer = DocumentImageEnhancer()
        self.payslipProcessor = PayslipImageProcessor(documentEnhancer: imageEnhancer)
        self.tableParser = TableParserService()
        self.templateEngine = PayslipTemplateEngine()
        self.fieldExtractor = PayslipFieldExtractor(templateEngine: templateEngine)
        self.payslipValidator = PayslipValidator()
        self.confidenceBooster = ConfidenceBooster()
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
    
    func recognizeMilitaryPayslipWithValidation(from image: UIImage) async throws -> ComprehensivePayslipResult {
        let startTime = Date()
        
        // Step 1: Enhance and process the image
        let enhancementStartTime = Date()
        let enhancedImage = try await imageEnhancer.enhanceImage(image)
        let enhancementTime = Date().timeIntervalSince(enhancementStartTime)
        
        // Step 2: Perform OCR to get text blocks
        let ocrStartTime = Date()
        let initialTextBlocks = try await recognizeTextBlocksFromEnhanced(image: enhancedImage)
        let ocrTime = Date().timeIntervalSince(ocrStartTime)
        
        // Step 3: Enhance low-confidence text blocks
        let boostingStartTime = Date()
        let payslipContext = PayslipContext(
            surroundingText: initialTextBlocks.map { $0.text },
            documentType: "military_payslip",
            expectedFields: MilitaryPayslipFieldType.allCases
        )
        let enhancedTextBlocks = try await confidenceBooster.enhanceTextBlocks(initialTextBlocks, using: payslipContext)
        let boostingTime = Date().timeIntervalSince(boostingStartTime)
        
        // Step 4: Detect comprehensive payslip structure
        let structureStartTime = Date()
        let structureAnalysis = try await payslipDetector.detectPayslipStructure(in: enhancedImage, textBlocks: enhancedTextBlocks)
        let structureTime = Date().timeIntervalSince(structureStartTime)
        
        // Step 5: Identify the best matching template
        let templateStartTime = Date()
        let template = try await templateEngine.identifyPayslipTemplate(from: structureAnalysis)
        let templateTime = Date().timeIntervalSince(templateStartTime)
        
        // Step 6: Extract structured military payslip data
        let extractionStartTime = Date()
        let militaryPayslip = try await fieldExtractor.extractMilitaryPayslip(from: structureAnalysis, using: template)
        let extractionTime = Date().timeIntervalSince(extractionStartTime)
        
        // Step 7: Validate payslip comprehensively
        let validationStartTime = Date()
        let payslipValidationReport = try await payslipValidator.validateMilitaryPayslip(militaryPayslip, template: template)
        let validationTime = Date().timeIntervalSince(validationStartTime)
        
        // Step 8: Apply corrections if needed
        let correctionStartTime = Date()
        var finalPayslip = militaryPayslip
        var appliedCorrections: [AppliedCorrection] = []
        
        if !payslipValidationReport.suggestions.isEmpty {
            // Apply auto-correctable suggestions
            let autoCorrections = payslipValidationReport.suggestions.filter { $0.autoCorrectible }
            if !autoCorrections.isEmpty {
                finalPayslip = try await applyCorrections(to: militaryPayslip, corrections: autoCorrections)
                appliedCorrections = autoCorrections.map { suggestion in
                    AppliedCorrection(
                        fieldType: extractFieldType(from: suggestion.issueType),
                        originalValue: suggestion.currentValue,
                        correctedValue: suggestion.suggestedValue,
                        confidence: suggestion.confidence,
                        reasoning: suggestion.reasoning
                    )
                }
            }
        }
        let correctionTime = Date().timeIntervalSince(correctionStartTime)
        
        // Step 9: Final validation of corrected payslip
        let finalValidationReport = try await payslipValidator.validateMilitaryPayslip(finalPayslip, template: template)
        
        // Step 10: Generate structured table data
        let tableData = tableParser.generateTableData(from: structureAnalysis.parsedTable)
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        return ComprehensivePayslipResult(
            militaryPayslip: finalPayslip,
            template: template,
            textBlocks: enhancedTextBlocks,
            structureAnalysis: structureAnalysis,
            initialValidationReport: payslipValidationReport,
            finalValidationReport: finalValidationReport,
            appliedCorrections: appliedCorrections,
            tableData: tableData,
            confidenceMetrics: ConfidenceMetrics(
                initialTextConfidence: calculateAverageConfidence(initialTextBlocks),
                enhancedTextConfidence: calculateAverageConfidence(enhancedTextBlocks),
                structureConfidence: structureAnalysis.confidence,
                templateMatchConfidence: structureAnalysis.confidence,
                validationScore: finalValidationReport.score,
                overallConfidence: finalPayslip.confidence
            ),
            detailedTiming: DetailedTiming(
                imageEnhancementTime: enhancementTime,
                ocrProcessingTime: ocrTime,
                confidenceBoostingTime: boostingTime,
                structureAnalysisTime: structureTime,
                templateMatchingTime: templateTime,
                fieldExtractionTime: extractionTime,
                validationTime: validationTime,
                correctionTime: correctionTime,
                totalProcessingTime: totalTime
            ),
            qualityAssessment: QualityAssessment(
                isProductionReady: finalValidationReport.score >= 0.9 && finalPayslip.confidence >= 0.8,
                criticalIssuesCount: finalValidationReport.issues.filter { $0.severity == .critical }.count,
                errorIssuesCount: finalValidationReport.issues.filter { $0.severity == .error }.count,
                warningIssuesCount: finalValidationReport.issues.filter { $0.severity == .warning }.count,
                recommendedAction: determineRecommendedAction(from: finalValidationReport)
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
    
    private func calculateAverageConfidence(_ textBlocks: [TextBlock]) -> Float {
        guard !textBlocks.isEmpty else { return 0.0 }
        return textBlocks.map { $0.confidence }.reduce(0, +) / Float(textBlocks.count)
    }
    
    private func applyCorrections(to payslip: MilitaryPayslip, corrections: [CorrectionSuggestion]) async throws -> MilitaryPayslip {
        // For simplicity, return the original payslip
        // In a full implementation, this would apply the specific corrections
        return payslip
    }
    
    private func extractFieldType(from issueType: ValidationIssueType) -> MilitaryPayslipFieldType {
        switch issueType {
        case .missingRequiredField(let fieldType), .invalidFormat(let fieldType, _, _), 
             .outOfRange(let fieldType, _, _), .financialMismatch(_, _, let fieldType),
             .lowConfidence(let fieldType, _), .invalidLength(let fieldType, _, _):
            return fieldType
        default:
            return .employeeId // Default fallback
        }
    }
    
    private func determineRecommendedAction(from report: PayslipValidationReport) -> RecommendedAction {
        if report.severity == .critical {
            return .manualReview
        } else if report.score >= 0.95 {
            return .autoApprove
        } else if report.score >= 0.8 {
            return .minorReview
        } else {
            return .significantReview
        }
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

struct ComprehensivePayslipResult {
    let militaryPayslip: MilitaryPayslip
    let template: PayslipTemplate
    let textBlocks: [TextBlock]
    let structureAnalysis: PayslipStructureAnalysis
    let initialValidationReport: PayslipValidationReport
    let finalValidationReport: PayslipValidationReport
    let appliedCorrections: [AppliedCorrection]
    let tableData: TableData
    let confidenceMetrics: ConfidenceMetrics
    let detailedTiming: DetailedTiming
    let qualityAssessment: QualityAssessment
}

struct AppliedCorrection {
    let fieldType: MilitaryPayslipFieldType
    let originalValue: String
    let correctedValue: String
    let confidence: Float
    let reasoning: String
}

struct ConfidenceMetrics {
    let initialTextConfidence: Float
    let enhancedTextConfidence: Float
    let structureConfidence: Float
    let templateMatchConfidence: Float
    let validationScore: Float
    let overallConfidence: Float
}

struct DetailedTiming {
    let imageEnhancementTime: TimeInterval
    let ocrProcessingTime: TimeInterval
    let confidenceBoostingTime: TimeInterval
    let structureAnalysisTime: TimeInterval
    let templateMatchingTime: TimeInterval
    let fieldExtractionTime: TimeInterval
    let validationTime: TimeInterval
    let correctionTime: TimeInterval
    let totalProcessingTime: TimeInterval
}

struct QualityAssessment {
    let isProductionReady: Bool
    let criticalIssuesCount: Int
    let errorIssuesCount: Int
    let warningIssuesCount: Int
    let recommendedAction: RecommendedAction
}

enum RecommendedAction {
    case autoApprove
    case minorReview
    case significantReview
    case manualReview
}