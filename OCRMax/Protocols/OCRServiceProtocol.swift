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
    func setLanguage(_ language: String)
    func getSupportedLanguages() -> [String]
}

protocol EnhancedOCRServiceProtocol: OCRServiceProtocol {
    func recognizeTextBlocks(from image: UIImage) async throws -> [TextBlock]
    func recognizeTextBlocks(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> [TextBlock]
}

protocol PDFProcessorProtocol {
    func extractImages(from url: URL) throws -> [UIImage]
    func extractImagesBatch(from url: URL, batchSize: Int, batchHandler: @escaping ([UIImage], Int, Int) throws -> Void) throws
    func getPageCount(from url: URL) -> Int
    func extractTextFromPDF(url: URL) throws -> String
}

protocol DocumentExporterProtocol {
    func exportDocument(from text: String, format: DocumentFormat) throws -> URL
    func exportDocument(from textBlocks: [TextBlock], layoutAnalysis: LayoutAnalysis, format: DocumentFormat) throws -> URL
}

protocol ProgressReporting {
    func reportProgress(_ message: String)
    func reportCompletion()
    func reportError(_ error: Error)
}

protocol LayoutAnalyzerProtocol {
    func analyzeLayout(from textBlocks: [TextBlock]) -> LayoutAnalysis
    func detectColumns(in textBlocks: [TextBlock]) -> [ColumnGroup]
    func calculateSpacing(between textBlocks: [TextBlock]) -> SpacingInfo
    func groupTextBlocks(_ textBlocks: [TextBlock]) -> [TextGroup]
}

protocol SubscriptionManagerProtocol {
    var isPremiumUser: Bool { get }
    var currentTier: SubscriptionTier { get }
    func checkSubscriptionStatus() async
    func canUseFeature(_ feature: PremiumFeature) -> Bool
    func requestPurchase(for tier: SubscriptionTier) async throws -> Bool
    func restorePurchases() async throws -> Bool
}

protocol AIFormattingServiceProtocol {
    func enhanceFormatting(text: String, layoutHints: LayoutAnalysis) async throws -> String
    func isAvailable() -> Bool
    func estimatedCost(for text: String) -> Double
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

enum FormattingLevel: String, CaseIterable {
    case basic = "Basic"
    case enhanced = "Enhanced Layout"
    case aiEnhanced = "AI Enhanced"
    
    var description: String {
        return self.rawValue
    }
    
    var requiresPremium: Bool {
        switch self {
        case .basic:
            return false
        case .enhanced, .aiEnhanced:
            return true
        }
    }
}

enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
    
    var monthlyPrice: Double {
        switch self {
        case .free: return 0.0
        case .premium: return 4.99
        }
    }
}

enum PremiumFeature: String, CaseIterable {
    case enhancedLayout = "enhanced_layout"
    case aiFormatting = "ai_formatting"
}

struct LayoutAnalysis {
    let columns: [ColumnGroup]
    let spacing: SpacingInfo
    let textGroups: [TextGroup]
    let suggestedIndentation: [IndentationLevel]
}

struct ColumnGroup {
    let textBlocks: [TextBlock]
    let boundingBox: CGRect
    let columnIndex: Int
}

struct SpacingInfo {
    let averageLineSpacing: CGFloat
    let averageWordSpacing: CGFloat
    let paragraphSpacing: CGFloat
}

struct TextGroup {
    let blocks: [TextBlock]
    let groupType: TextGroupType
    let confidence: Float
}

enum TextGroupType {
    case header
    case paragraph
    case list
    case table
    case caption
}

struct IndentationLevel {
    let textBlock: TextBlock
    let indentationPoints: CGFloat
}

enum OCRError: LocalizedError {
    case invalidImage
    case processingFailed
    case noTextFound
    case unsupportedFormat
    case fileAccessDenied
    case subscriptionRequired
    case aiServiceUnavailable
    
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
        case .subscriptionRequired:
            return "Premium subscription required for this feature"
        case .aiServiceUnavailable:
            return "AI formatting service is currently unavailable"
        }
    }
}