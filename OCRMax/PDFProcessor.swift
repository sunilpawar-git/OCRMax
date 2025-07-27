//
//  PDFProcessor.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import PDFKit
import UIKit

class PDFProcessor {
    
    enum ProcessingError: Error {
        case invalidURL
        case invalidPDF
        case pageExtractionFailed
    }
    
    func extractImagesFromPDF(url: URL) throws -> [UIImage] {
        guard url.startAccessingSecurityScopedResource() else {
            throw ProcessingError.invalidURL
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ProcessingError.invalidPDF
        }
        
        var images: [UIImage] = []
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            let pageImage = renderPDFPageAsImage(page: page, scale: 2.0)
            images.append(pageImage)
        }
        
        guard !images.isEmpty else {
            throw ProcessingError.pageExtractionFailed
        }
        
        return images
    }
    
    private func renderPDFPageAsImage(page: PDFPage, scale: CGFloat = 1.0) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        
        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
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
            throw ProcessingError.invalidURL
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ProcessingError.invalidPDF
        }
        
        var extractedText = ""
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            if let pageText = page.string {
                extractedText += "--- Page \(pageIndex + 1) ---\n"
                extractedText += pageText
                extractedText += "\n\n"
            }
        }
        
        return extractedText
    }
}