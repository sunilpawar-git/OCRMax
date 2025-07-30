//
//  DocumentImageEnhancer.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import UIKit
import CoreImage
import Vision

protocol DocumentImageEnhancerProtocol {
    func enhanceImage(_ image: UIImage) async throws -> UIImage
    func enhanceImages(_ images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> [UIImage]
}

final class DocumentImageEnhancer: DocumentImageEnhancerProtocol {
    
    private let context = CIContext()
    
    enum EnhancementError: LocalizedError {
        case invalidImage
        case processingFailed
        case noImageData
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid image provided for enhancement"
            case .processingFailed:
                return "Image processing failed during enhancement"
            case .noImageData:
                return "No image data available for processing"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func enhanceImage(_ image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw EnhancementError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let enhancedImage = try await processImage(ciImage)
                    continuation.resume(returning: enhancedImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func enhanceImages(_ images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> [UIImage] {
        var enhancedImages: [UIImage] = []
        let totalImages = images.count
        
        for (index, image) in images.enumerated() {
            progressHandler("Enhancing image \(index + 1) of \(totalImages)...")
            
            do {
                let enhanced = try await enhanceImage(image)
                enhancedImages.append(enhanced)
            } catch {
                progressHandler("Warning: Failed to enhance image \(index + 1), using original")
                enhancedImages.append(image)
            }
        }
        
        progressHandler("Image enhancement completed")
        return enhancedImages
    }
    
    // MARK: - Private Enhancement Pipeline
    
    private func processImage(_ ciImage: CIImage) async throws -> UIImage {
        var processedImage = ciImage
        
        // Step 1: Perspective correction (if needed)
        processedImage = try await correctPerspective(processedImage)
        
        // Step 2: Noise reduction
        processedImage = applyNoiseReduction(processedImage)
        
        // Step 3: Adaptive thresholding for better contrast
        processedImage = applyAdaptiveThresholding(processedImage)
        
        // Step 4: Sharpening
        processedImage = applySharpeningFilter(processedImage)
        
        // Step 5: Resolution optimization
        processedImage = optimizeResolution(processedImage)
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            throw EnhancementError.processingFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Enhancement Filters
    
    private func correctPerspective(_ image: CIImage) async throws -> CIImage {
        // Use Vision framework to detect document bounds
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation],
                      let rect = observations.first else {
                    // No rectangle detected, return original
                    continuation.resume(returning: image)
                    return
                }
                
                // Apply perspective correction
                let correctedImage = self.applyPerspectiveCorrection(to: image, using: rect)
                continuation.resume(returning: correctedImage)
            }
            
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 3.0
            request.minimumSize = 0.1
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func applyPerspectiveCorrection(to image: CIImage, using rectangle: VNRectangleObservation) -> CIImage {
        let imageSize = image.extent.size
        
        // Convert normalized coordinates to image coordinates
        let topLeft = CGPoint(
            x: rectangle.topLeft.x * imageSize.width,
            y: (1 - rectangle.topLeft.y) * imageSize.height
        )
        let topRight = CGPoint(
            x: rectangle.topRight.x * imageSize.width,
            y: (1 - rectangle.topRight.y) * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: rectangle.bottomLeft.x * imageSize.width,
            y: (1 - rectangle.bottomLeft.y) * imageSize.height
        )
        let bottomRight = CGPoint(
            x: rectangle.bottomRight.x * imageSize.width,
            y: (1 - rectangle.bottomRight.y) * imageSize.height
        )
        
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
            return image
        }
        
        perspectiveFilter.setValue(image, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        return perspectiveFilter.outputImage ?? image
    }
    
    private func applyNoiseReduction(_ image: CIImage) -> CIImage {
        guard let noiseFilter = CIFilter(name: "CINoiseReduction") else {
            return image
        }
        
        noiseFilter.setValue(image, forKey: kCIInputImageKey)
        noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
        noiseFilter.setValue(0.40, forKey: "inputSharpness")
        
        return noiseFilter.outputImage ?? image
    }
    
    private func applyAdaptiveThresholding(_ image: CIImage) -> CIImage {
        // Convert to grayscale first
        guard let grayscaleFilter = CIFilter(name: "CIPhotoEffectNoir") else {
            return image
        }
        grayscaleFilter.setValue(image, forKey: kCIInputImageKey)
        let grayscaleImage = grayscaleFilter.outputImage ?? image
        
        // Apply contrast enhancement
        guard let contrastFilter = CIFilter(name: "CIColorControls") else {
            return grayscaleImage
        }
        
        contrastFilter.setValue(grayscaleImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.8, forKey: kCIInputContrastKey)  // Increase contrast
        contrastFilter.setValue(0.2, forKey: kCIInputBrightnessKey) // Slight brightness boost
        contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Keep grayscale
        
        return contrastFilter.outputImage ?? grayscaleImage
    }
    
    private func applySharpeningFilter(_ image: CIImage) -> CIImage {
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else {
            return image
        }
        
        sharpenFilter.setValue(image, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.8, forKey: kCIInputSharpnessKey)
        
        return sharpenFilter.outputImage ?? image
    }
    
    private func optimizeResolution(_ image: CIImage) -> CIImage {
        let targetWidth: CGFloat = 1600  // Optimal width for OCR
        let currentWidth = image.extent.width
        
        // Only scale if image is significantly larger or smaller
        guard currentWidth != targetWidth && (currentWidth < 800 || currentWidth > 2400) else {
            return image
        }
        
        let scale = targetWidth / currentWidth
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        
        return image.transformed(by: transform)
    }
}

// MARK: - Configuration Extensions

extension DocumentImageEnhancer {
    
    struct EnhancementSettings {
        let noiseLevel: Float
        let sharpness: Float
        let contrast: Float
        let brightness: Float
        let targetWidth: CGFloat
        
        static let `default` = EnhancementSettings(
            noiseLevel: 0.02,
            sharpness: 0.8,
            contrast: 1.8,
            brightness: 0.2,
            targetWidth: 1600
        )
        
        static let documentOptimized = EnhancementSettings(
            noiseLevel: 0.01,
            sharpness: 1.0,
            contrast: 2.0,
            brightness: 0.1,
            targetWidth: 1800
        )
    }
} 