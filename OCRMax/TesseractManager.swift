//
//  TesseractManager.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import UIKit

class TesseractManager {
    
    enum TesseractError: Error {
        case initializationFailed
        case recognitionFailed
        case imagePreprocessingFailed
        case languageDataNotFound
    }
    
    private var isInitialized = false
    
    init() {
        setupTesseract()
    }
    
    private func setupTesseract() {
        isInitialized = true
    }
    
    func recognizeText(from image: UIImage, language: String = "eng") async throws -> String {
        guard isInitialized else {
            throw TesseractError.initializationFailed
        }
        
        let preprocessedImage = preprocessImage(image)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let recognizedText = try self.performTesseractRecognition(on: preprocessedImage, language: language)
                    continuation.resume(returning: recognizedText)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performTesseractRecognition(on image: UIImage, language: String) throws -> String {
        let text = """
        This is a placeholder for Tesseract OCR integration.
        To fully implement Tesseract:
        
        1. Add SwiftyTesseract or TesseractOCR library
        2. Download language training data files
        3. Bundle them with the app
        4. Initialize Tesseract with proper paths
        5. Configure recognition parameters
        
        Current implementation uses Vision framework only.
        """
        
        return text
    }
    
    private func preprocessImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let grayContext = context else { return image }
        
        grayContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let grayImage = grayContext.makeImage() else { return image }
        
        return UIImage(cgImage: grayImage)
    }
    
    func enhanceImageForOCR(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let enhancedContext = context else { return image }
        
        enhancedContext.interpolationQuality = .high
        enhancedContext.setShouldAntialias(false)
        enhancedContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let enhancedImage = enhancedContext.makeImage() else { return image }
        
        return UIImage(cgImage: enhancedImage)
    }
    
    func getSupportedLanguages() -> [String] {
        return ["eng", "fra", "deu", "spa", "ita", "por", "rus", "jpn", "chi_sim", "chi_tra", "kor", "ara", "hin"]
    }
    
    func isLanguageSupported(_ language: String) -> Bool {
        return getSupportedLanguages().contains(language)
    }
}