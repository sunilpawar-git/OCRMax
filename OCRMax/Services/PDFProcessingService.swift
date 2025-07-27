//
//  PDFProcessingService.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import PDFKit
import UIKit

final class PDFProcessingService: PDFProcessorProtocol {
    
    private let imageScale: CGFloat
    private let imageQuality: CGInterpolationQuality
    
    init(imageScale: CGFloat = 2.0, imageQuality: CGInterpolationQuality = .high) {
        self.imageScale = imageScale
        self.imageQuality = imageQuality
    }
    
    func extractImages(from url: URL) throws -> [UIImage] {
        guard url.startAccessingSecurityScopedResource() else {
            throw OCRError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw OCRError.unsupportedFormat
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw OCRError.noTextFound
        }
        
        var images: [UIImage] = []
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            let pageImage = renderPageAsImage(page: page)
            images.append(pageImage)
        }
        
        guard !images.isEmpty else {
            throw OCRError.processingFailed
        }
        
        return images
    }
    
    func getPageCount(from url: URL) -> Int {
        guard url.startAccessingSecurityScopedResource() else {
            return 0
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            return 0
        }
        
        return pdfDocument.pageCount
    }
    
    func extractTextFromPDF(url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw OCRError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw OCRError.unsupportedFormat
        }
        
        var extractedText = ""
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }
            
            if !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedText += "--- Page \(pageIndex + 1) ---\n"
                extractedText += pageText
                extractedText += "\n\n"
            }
        }
        
        return extractedText
    }
    
    private func renderPageAsImage(page: PDFPage) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)
        let scaledSize = CGSize(
            width: pageRect.width * imageScale,
            height: pageRect.height * imageScale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        
        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.interpolationQuality = imageQuality
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: imageScale, y: -imageScale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}