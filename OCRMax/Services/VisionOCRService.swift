//
//  VisionOCRService.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import Vision
import UIKit

final class VisionOCRService: OCRServiceProtocol {
    
    private let requestConfiguration: VNRecognizeTextRequestConfiguration
    
    init(configuration: VNRecognizeTextRequestConfiguration = VisionOCRService.defaultConfiguration()) {
        self.requestConfiguration = configuration
    }
    
    func recognizeText(from image: UIImage) async throws -> String {
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
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: recognizedText)
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
    
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String {
        var allText = ""
        let totalImages = images.count
        
        for (index, image) in images.enumerated() {
            progressHandler("Processing page \(index + 1) of \(totalImages)...")
            
            do {
                let pageText = try await recognizeText(from: image)
                if !pageText.isEmpty {
                    allText += "--- Page \(index + 1) ---\n"
                    allText += pageText
                    allText += "\n\n"
                }
            } catch {
                progressHandler("Warning: Failed to process page \(index + 1)")
                continue
            }
        }
        
        progressHandler("OCR processing completed")
        
        if allText.isEmpty {
            throw OCRError.noTextFound
        }
        
        return allText
    }
    
    private func configureRequest(_ request: VNRecognizeTextRequest) {
        request.recognitionLevel = requestConfiguration.recognitionLevel
        request.recognitionLanguages = requestConfiguration.recognitionLanguages
        request.usesLanguageCorrection = requestConfiguration.usesLanguageCorrection
    }
    
    private static func defaultConfiguration() -> VNRecognizeTextRequestConfiguration {
        var config = VNRecognizeTextRequestConfiguration()
        config.recognitionLevel = .accurate
        config.recognitionLanguages = ["en-US"]
        config.usesLanguageCorrection = true
        return config
    }
}

struct VNRecognizeTextRequestConfiguration {
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var recognitionLanguages: [String] = ["en-US"]
    var usesLanguageCorrection: Bool = true
}