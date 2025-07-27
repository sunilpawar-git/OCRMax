//
//  OCRServiceProtocol.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import UIKit

protocol OCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> String
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String
}

protocol PDFProcessorProtocol {
    func extractImages(from url: URL) throws -> [UIImage]
    func getPageCount(from url: URL) -> Int
    func extractTextFromPDF(url: URL) throws -> String
}

protocol DocumentExporterProtocol {
    func exportDocument(from text: String, format: DocumentFormat) throws -> URL
}

protocol ProgressReporting {
    func reportProgress(_ message: String)
    func reportCompletion()
    func reportError(_ error: Error)
}

enum DocumentFormat {
    case rtf
    case docx
    case txt
    
    var fileExtension: String {
        switch self {
        case .rtf: return "rtf"
        case .docx: return "docx"
        case .txt: return "txt"
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case processingFailed
    case noTextFound
    case unsupportedFormat
    case fileAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for OCR processing"
        case .processingFailed:
            return "OCR processing failed"
        case .noTextFound:
            return "No text found in the provided image"
        case .unsupportedFormat:
            return "Unsupported file format"
        case .fileAccessDenied:
            return "File access denied"
        }
    }
}