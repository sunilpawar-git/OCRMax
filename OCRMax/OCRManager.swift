//
//  OCRManager.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import Vision
import UIKit
import PDFKit

@MainActor
class OCRManager: ObservableObject {
    
    enum OCRError: Error {
        case invalidPDF
        case noImagesFound
        case ocrFailed
        case tesseractNotAvailable
    }
    
    func processPDF(url: URL, progressHandler: @escaping (String) -> Void) async throws -> String {
        progressHandler("Opening PDF...")
        
        guard url.startAccessingSecurityScopedResource() else {
            throw OCRError.invalidPDF
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw OCRError.invalidPDF
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw OCRError.noImagesFound
        }
        
        var allText = ""
        
        for pageIndex in 0..<pageCount {
            progressHandler("Processing page \(pageIndex + 1) of \(pageCount)...")
            
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            let pageImage = renderPDFPageToImage(page: page)
            
            let visionText = try await performVisionOCR(on: pageImage)
            
            if !visionText.isEmpty {
                allText += "--- Page \(pageIndex + 1) ---\n"
                allText += visionText
                allText += "\n\n"
            }
        }
        
        if allText.isEmpty {
            throw OCRError.ocrFailed
        }
        
        progressHandler("OCR completed successfully!")
        return allText
    }
    
    private func renderPDFPageToImage(page: PDFPage) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        
        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
    
    private func performVisionOCR(on image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: OCRError.ocrFailed)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.ocrFailed)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func performTesseractOCR(on image: UIImage) throws -> String {
        return "Tesseract OCR integration placeholder - requires SwiftyTesseract library"
    }
    
    func processWithBothEngines(image: UIImage, progressHandler: @escaping (String) -> Void) async throws -> String {
        progressHandler("Running Vision OCR...")
        let visionText = try await performVisionOCR(on: image)
        
        progressHandler("Running Tesseract OCR...")
        let tesseractText = try performTesseractOCR(on: image)
        
        var combinedText = ""
        if !visionText.isEmpty {
            combinedText += "=== Vision OCR Results ===\n"
            combinedText += visionText
            combinedText += "\n\n"
        }
        
        if !tesseractText.isEmpty && !tesseractText.contains("placeholder") {
            combinedText += "=== Tesseract OCR Results ===\n"
            combinedText += tesseractText
            combinedText += "\n\n"
        }
        
        return combinedText.isEmpty ? visionText : combinedText
    }
}