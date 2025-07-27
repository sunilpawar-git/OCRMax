//
//  TesseractOCRService.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import UIKit

final class TesseractOCRService: OCRServiceProtocol {
    
    private let currentLanguage: String
    
    enum TesseractOCRError: LocalizedError {
        case initializationFailed
        case recognitionFailed
        case invalidImage
        case languageNotSupported
        case libraryNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .initializationFailed:
                return "Failed to initialize Tesseract OCR engine"
            case .recognitionFailed:
                return "Text recognition failed using Tesseract"
            case .invalidImage:
                return "Invalid image provided for Tesseract OCR"
            case .languageNotSupported:
                return "Selected language is not supported by Tesseract"
            case .libraryNotAvailable:
                return "SwiftyTesseract library is not available. Please add it as a dependency to enable Tesseract OCR."
            }
        }
    }
    
    init(language: String = "eng") {
        self.currentLanguage = language
        configureEngine()
    }
    
    private func configureEngine() {
        // Configuration for Tesseract engine
        // This would be implemented when SwiftyTesseract is available
    }
    
    func recognizeText(from image: UIImage) async throws -> String {
        // Fallback implementation - returns a message explaining Tesseract is not available
        return """
        Tesseract OCR Service - Fallback Mode
        
        To enable full Tesseract OCR functionality:
        1. Add SwiftyTesseract package dependency
        2. Download and bundle Tesseract training data files
        3. Configure the project for Tesseract integration
        
        Current language setting: \(currentLanguage)
        
        For now, please use the Apple Vision OCR engine which is fully functional.
        """
    }
    
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String {
        var allText = ""
        let totalImages = images.count
        
        for (index, image) in images.enumerated() {
            do {
                let text = try await recognizeText(from: image)
                allText += text + "\n\n"
                
                let progressMessage = "Processing page \(index + 1) of \(totalImages) with Tesseract (Fallback Mode)..."
                progressHandler(progressMessage)
                
                // Simulate processing time
                try await Task.sleep(nanoseconds: 500_000_000)
                
            } catch {
                let errorMessage = "Failed to process page \(index + 1): \(error.localizedDescription)"
                progressHandler(errorMessage)
                continue
            }
        }
        
        guard !allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.noTextFound
        }
        
        return allText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        grayContext.interpolationQuality = .high
        grayContext.setShouldAntialias(false)
        grayContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let grayImage = grayContext.makeImage() else { return image }
        
        return UIImage(cgImage: grayImage)
    }
    
    // Configuration methods for when SwiftyTesseract is available
    func setLanguage(_ language: String) {
        // Would configure Tesseract language when available
    }
    
    func setPageSegmentationMode(_ mode: Int) {
        // Would configure page segmentation when available
    }
    
    func setEngineMode(_ mode: Int) {
        // Would configure engine mode when available
    }
    
    func setCharacterWhitelist(_ whitelist: String?) {
        // Would configure character whitelist when available
    }
    
    func setCharacterBlacklist(_ blacklist: String?) {
        // Would configure character blacklist when available
    }
    
    func getSupportedLanguages() -> [String] {
        return ["eng", "fra", "deu", "spa", "ita", "por", "rus", "jpn", "chi_sim", "chi_tra", "kor", "ara", "hin"]
    }
    
    func isLanguageSupported(_ language: String) -> Bool {
        return getSupportedLanguages().contains(language)
    }
    
    func isSwiftyTesseractAvailable() -> Bool {
        #if canImport(SwiftyTesseract)
        return true
        #else
        return false
        #endif
    }
}