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
    
    init(configuration: VNRecognizeTextRequestConfiguration = EnhancedVisionOCRService.defaultConfiguration()) {
        self.visionService = VisionOCRService(configuration: configuration)
    }
    
    // MARK: - Enhanced OCR Methods
    
    func recognizeTextBlocks(from image: UIImage) async throws -> [TextBlock] {
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
    
    func recognizeTextBlocks(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> [TextBlock] {
        var allTextBlocks: [TextBlock] = []
        let totalImages = images.count
        
        for (index, image) in images.enumerated() {
            progressHandler("Processing page \(index + 1) of \(totalImages)...")
            
            do {
                let pageTextBlocks = try await recognizeTextBlocks(from: image)
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
    
    private static func defaultConfiguration() -> VNRecognizeTextRequestConfiguration {
        var config = VNRecognizeTextRequestConfiguration()
        config.recognitionLevel = .accurate
        config.recognitionLanguages = ["en-US"]
        config.usesLanguageCorrection = true
        return config
    }
}