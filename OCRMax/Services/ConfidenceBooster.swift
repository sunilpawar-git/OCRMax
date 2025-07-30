//
//  ConfidenceBooster.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import UIKit
import Vision

protocol ConfidenceBoosterProtocol {
    func enhanceTextBlocks(_ textBlocks: [TextBlock], using context: PayslipContext) async throws -> [TextBlock]
    func reprocessLowConfidenceFields(_ fields: [MilitaryPayslipField], originalImage: UIImage) async throws -> [MilitaryPayslipField]
    func applyContextualCorrection(_ text: String, context: FieldContext) -> CorrectionResult
    func validateWithDictionary(_ text: String, fieldType: MilitaryPayslipFieldType) -> DictionaryValidationResult
}

final class ConfidenceBooster: ConfidenceBoosterProtocol {
    
    private let lowConfidenceThreshold: Float = 0.7
    private let reprocessThreshold: Float = 0.5
    private let militaryDictionary: MilitaryDictionary
    private let financialValidator: FinancialPatternValidator
    
    init() {
        self.militaryDictionary = MilitaryDictionary()
        self.financialValidator = FinancialPatternValidator()
    }
    
    enum BoostingError: LocalizedError {
        case reprocessingFailed
        case contextInsufficient
        case validationFailed
        
        var errorDescription: String? {
            switch self {
            case .reprocessingFailed:
                return "Failed to reprocess low confidence text"
            case .contextInsufficient:
                return "Insufficient context for correction"
            case .validationFailed:
                return "Validation against dictionary failed"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func enhanceTextBlocks(_ textBlocks: [TextBlock], using context: PayslipContext) async throws -> [TextBlock] {
        var enhancedBlocks: [TextBlock] = []
        
        for textBlock in textBlocks {
            if textBlock.confidence < lowConfidenceThreshold {
                // Try to enhance this low-confidence block
                let enhancedBlock = try await enhanceTextBlock(textBlock, context: context)
                enhancedBlocks.append(enhancedBlock)
            } else {
                enhancedBlocks.append(textBlock)
            }
        }
        
        return enhancedBlocks
    }
    
    func reprocessLowConfidenceFields(_ fields: [MilitaryPayslipField], originalImage: UIImage) async throws -> [MilitaryPayslipField] {
        var improvedFields: [MilitaryPayslipField] = []
        
        for field in fields {
            if field.confidence < reprocessThreshold {
                // Attempt to improve this field
                let improvedField = try await reprocessField(field, originalImage: originalImage)
                improvedFields.append(improvedField)
            } else {
                improvedFields.append(field)
            }
        }
        
        return improvedFields
    }
    
    func applyContextualCorrection(_ text: String, context: FieldContext) -> CorrectionResult {
        var correctedText = text
        var confidenceBoost: Float = 0.0
        var corrections: [String] = []
        
        // Apply field-specific corrections
        switch context.fieldType {
        case .employeeId:
            (correctedText, confidenceBoost) = correctEmployeeId(text, context: context)
            
        case .employeeName:
            (correctedText, confidenceBoost) = correctEmployeeName(text, context: context)
            
        case .panNumber:
            (correctedText, confidenceBoost) = correctPANNumber(text, context: context)
            
        case .basicPay, .gradePay, .totalEarnings, .totalDeductions, .netPay:
            (correctedText, confidenceBoost) = correctFinancialAmount(text, context: context)
            
        case .designation:
            (correctedText, confidenceBoost) = correctMilitaryDesignation(text, context: context)
            
        case .bankName:
            (correctedText, confidenceBoost) = correctBankName(text, context: context)
            
        case .accountNumber:
            (correctedText, confidenceBoost) = correctAccountNumber(text, context: context)
            
        case .payPeriod, .payMonth, .payYear:
            (correctedText, confidenceBoost) = correctDateField(text, context: context)
            
        default:
            (correctedText, confidenceBoost) = applyGenericCorrection(text, context: context)
        }
        
        if correctedText != text {
            corrections.append("Corrected '\(text)' to '\(correctedText)'")
        }
        
        return CorrectionResult(
            originalText: text,
            correctedText: correctedText,
            confidenceBoost: confidenceBoost,
            corrections: corrections,
            wasModified: correctedText != text
        )
    }
    
    func validateWithDictionary(_ text: String, fieldType: MilitaryPayslipFieldType) -> DictionaryValidationResult {
        switch fieldType {
        case .designation:
            return militaryDictionary.validateRank(text)
        case .department:
            return militaryDictionary.validateUnit(text)
        case .bankName:
            return militaryDictionary.validateBankName(text)
        default:
            return DictionaryValidationResult(
                isValid: true,
                confidence: 1.0,
                suggestions: [],
                matchType: .exact
            )
        }
    }
    
    // MARK: - Private Enhancement Methods
    
    private func enhanceTextBlock(_ textBlock: TextBlock, context: PayslipContext) async throws -> TextBlock {
        // Try multiple enhancement strategies
        var bestResult = textBlock
        var bestConfidence = textBlock.confidence
        
        // Strategy 1: Context-based correction
        let contextResult = applyContextualCorrection(textBlock.text, context: FieldContext(
            fieldType: .employeeName, // Default, would need better context detection
            surroundingText: context.surroundingText,
            expectedPattern: nil,
            position: textBlock.boundingBox
        ))
        
        if contextResult.confidenceBoost > 0 {
            let newConfidence = min(textBlock.confidence + contextResult.confidenceBoost, 1.0)
            if newConfidence > bestConfidence {
                bestResult = TextBlock(
                    text: contextResult.correctedText,
                    boundingBox: textBlock.boundingBox,
                    confidence: newConfidence,
                    pageIndex: textBlock.pageIndex
                )
                bestConfidence = newConfidence
            }
        }
        
        // Strategy 2: Dictionary validation
        let dictionaryResult = validateWithDictionary(textBlock.text, fieldType: .employeeName)
        if dictionaryResult.confidence > bestConfidence {
            let suggestion = dictionaryResult.suggestions.first ?? textBlock.text
            bestResult = TextBlock(
                text: suggestion,
                boundingBox: textBlock.boundingBox,
                confidence: dictionaryResult.confidence,
                pageIndex: textBlock.pageIndex
            )
            bestConfidence = dictionaryResult.confidence
        }
        
        // Strategy 3: Pattern matching
        let patternResult = applyPatternMatching(textBlock.text, expectedType: inferFieldType(from: textBlock, context: context))
        if patternResult.confidenceBoost > 0 {
            let newConfidence = min(textBlock.confidence + patternResult.confidenceBoost, 1.0)
            if newConfidence > bestConfidence {
                bestResult = TextBlock(
                    text: patternResult.correctedText,
                    boundingBox: textBlock.boundingBox,
                    confidence: newConfidence,
                    pageIndex: textBlock.pageIndex
                )
            }
        }
        
        return bestResult
    }
    
    private func reprocessField(_ field: MilitaryPayslipField, originalImage: UIImage) async throws -> MilitaryPayslipField {
        // This would involve re-running OCR on the specific region
        // For now, we'll apply enhanced correction algorithms
        
        let context = FieldContext(
            fieldType: field.type,
            surroundingText: [],
            expectedPattern: getExpectedPattern(for: field.type),
            position: CGRect.zero // Would need actual position
        )
        
        let correctionResult = applyContextualCorrection(field.value, context: context)
        
        let newConfidence = min(field.confidence + correctionResult.confidenceBoost, 1.0)
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctionResult.correctedText,
            confidence: newConfidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    // MARK: - Field-Specific Correction Methods
    
    private func correctEmployeeId(_ text: String, context: FieldContext) -> (String, Float) {
        var corrected = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        var boost: Float = 0.0
        
        // Common OCR errors for digits
        corrected = corrected
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "B", with: "8")
        
        // Validate length
        if corrected.count >= 5 && corrected.count <= 8 {
            boost = 0.2
        }
        
        return (corrected, boost)
    }
    
    private func correctEmployeeName(_ text: String, context: FieldContext) -> (String, Float) {
        var corrected = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        var boost: Float = 0.0
        
        // Remove common OCR artifacts
        corrected = corrected
            .replacingOccurrences(of: "[0-9]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^A-Z\\s]", with: "", options: .regularExpression)
        
        // Common character corrections
        corrected = corrected
            .replacingOccurrences(of: "0", with: "O")
            .replacingOccurrences(of: "1", with: "I")
            .replacingOccurrences(of: "5", with: "S")
        
        // Validate name length and format
        if corrected.count >= 2 && corrected.count <= 50 && !corrected.trimmingCharacters(in: .whitespaces).isEmpty {
            boost = 0.15
        }
        
        return (corrected, boost)
    }
    
    private func correctPANNumber(_ text: String, context: FieldContext) -> (String, Float) {
        var corrected = text
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        
        var boost: Float = 0.0
        
        // Common OCR errors in PAN
        corrected = corrected
            .replacingOccurrences(of: "0", with: "O")
            .replacingOccurrences(of: "1", with: "I")
        
        // Validate PAN format: ABCDE1234F
        let panPattern = "^[A-Z]{5}[0-9]{4}[A-Z]$"
        if corrected.range(of: panPattern, options: .regularExpression) != nil {
            boost = 0.3
        }
        
        return (corrected, boost)
    }
    
    private func correctFinancialAmount(_ text: String, context: FieldContext) -> (String, Float) {
        var corrected = text
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "Rs.", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        var boost: Float = 0.0
        
        // Common OCR errors in numbers
        corrected = corrected
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "l", with: "1")
        
        // Validate numeric format
        if Double(corrected.replacingOccurrences(of: ",", with: "")) != nil {
            boost = 0.2
        }
        
        return (corrected, boost)
    }
    
    private func correctMilitaryDesignation(_ text: String, context: FieldContext) -> (String, Float) {
        let corrected = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var boost: Float = 0.0
        
        let validationResult = militaryDictionary.validateRank(corrected)
        if validationResult.isValid {
            boost = 0.25
        } else if let bestSuggestion = validationResult.suggestions.first {
            return (bestSuggestion, 0.2)
        }
        
        return (corrected, boost)
    }
    
    private func correctBankName(_ text: String, context: FieldContext) -> (String, Float) {
        let corrected = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var boost: Float = 0.0
        
        let validationResult = militaryDictionary.validateBankName(corrected)
        if validationResult.isValid {
            boost = 0.2
        } else if let bestSuggestion = validationResult.suggestions.first {
            return (bestSuggestion, 0.15)
        }
        
        return (corrected, boost)
    }
    
    private func correctAccountNumber(_ text: String, context: FieldContext) -> (String, Float) {
        let corrected = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        var boost: Float = 0.0
        
        // Bank account numbers are typically 9-18 digits
        if corrected.count >= 9 && corrected.count <= 18 {
            boost = 0.15
        }
        
        return (corrected, boost)
    }
    
    private func correctDateField(_ text: String, context: FieldContext) -> (String, Float) {
        var corrected = text.replacingOccurrences(of: " ", with: "")
        var boost: Float = 0.0
        
        // Try to fix common date format issues
        let datePatterns = [
            ("(\\d{2})/(\\d{4})", "$1/$2"),  // MM/YYYY
            ("(\\d{1,2})-(\\d{4})", "$1/$2"), // M-YYYY or MM-YYYY
            ("(\\d{2})(\\d{4})", "$1/$2")     // MMYYYY
        ]
        
        for (pattern, replacement) in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(corrected.startIndex..., in: corrected)
                let result = regex.stringByReplacingMatches(
                    in: corrected,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
                
                if result != corrected {
                    corrected = result
                    boost = 0.15
                    break
                }
            }
        }
        
        return (corrected, boost)
    }
    
    private func applyGenericCorrection(_ text: String, context: FieldContext) -> (String, Float) {
        let corrected = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        let boost: Float = corrected != text ? 0.05 : 0.0
        
        return (corrected, boost)
    }
    
    // MARK: - Helper Methods
    
    private func inferFieldType(from textBlock: TextBlock, context: PayslipContext) -> MilitaryPayslipFieldType {
        // Basic inference based on text content and position
        let text = textBlock.text.uppercased()
        
        if text.range(of: "^[0-9]{5,8}$", options: .regularExpression) != nil {
            return .employeeId
        } else if text.range(of: "^[A-Z]{5}[0-9]{4}[A-Z]$", options: .regularExpression) != nil {
            return .panNumber
        } else if text.range(of: "^[0-9,]+$", options: .regularExpression) != nil {
            return .basicPay
        } else if text.contains("/") && text.count <= 10 {
            return .payPeriod
        } else {
            return .employeeName
        }
    }
    
    private func getExpectedPattern(for fieldType: MilitaryPayslipFieldType) -> String? {
        switch fieldType {
        case .employeeId:
            return "^[0-9]{5,8}$"
        case .panNumber:
            return "^[A-Z]{5}[0-9]{4}[A-Z]$"
        case .accountNumber:
            return "^[0-9]{9,18}$"
        case .ifscCode:
            return "^[A-Z]{4}0[A-Z0-9]{6}$"
        default:
            return nil
        }
    }
    
    private func applyPatternMatching(_ text: String, expectedType: MilitaryPayslipFieldType) -> CorrectionResult {
        guard let pattern = getExpectedPattern(for: expectedType) else {
            return CorrectionResult(
                originalText: text,
                correctedText: text,
                confidenceBoost: 0.0,
                corrections: [],
                wasModified: false
            )
        }
        
        if text.range(of: pattern, options: .regularExpression) != nil {
            return CorrectionResult(
                originalText: text,
                correctedText: text,
                confidenceBoost: 0.2,
                corrections: ["Pattern match confirmed"],
                wasModified: false
            )
        }
        
        return CorrectionResult(
            originalText: text,
            correctedText: text,
            confidenceBoost: 0.0,
            corrections: ["Pattern mismatch"],
            wasModified: false
        )
    }
}

// MARK: - Supporting Classes and Structures

class MilitaryDictionary {
    private let militaryRanks = [
        "SEPOY", "NAIK", "HAVILDAR", "SERGEANT", "COMPANY HAVILDAR MAJOR",
        "SUBEDAR", "NAIB SUBEDAR", "JCO",
        "SECOND LIEUTENANT", "LIEUTENANT", "CAPTAIN", "MAJOR", 
        "LIEUTENANT COLONEL", "COLONEL", "BRIGADIER", 
        "MAJOR GENERAL", "LIEUTENANT GENERAL", "GENERAL"
    ]
    
    private let bankNames = [
        "STATE BANK OF INDIA", "PUNJAB NATIONAL BANK", "BANK OF BARODA",
        "CANARA BANK", "UNION BANK", "INDIAN BANK", "CENTRAL BANK",
        "HDFC BANK", "ICICI BANK", "AXIS BANK"
    ]
    
    func validateRank(_ rank: String) -> DictionaryValidationResult {
        let normalizedRank = rank.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if militaryRanks.contains(normalizedRank) {
            return DictionaryValidationResult(
                isValid: true,
                confidence: 1.0,
                suggestions: [],
                matchType: .exact
            )
        }
        
        // Find close matches
        let suggestions = militaryRanks.filter { rank in
            normalizedRank.contains(rank) || rank.contains(normalizedRank)
        }
        
        return DictionaryValidationResult(
            isValid: false,
            confidence: suggestions.isEmpty ? 0.0 : 0.7,
            suggestions: suggestions,
            matchType: suggestions.isEmpty ? .none : .partial
        )
    }
    
    func validateUnit(_ unit: String) -> DictionaryValidationResult {
        // Simplified unit validation
        return DictionaryValidationResult(
            isValid: true,
            confidence: 0.8,
            suggestions: [],
            matchType: .fuzzy
        )
    }
    
    func validateBankName(_ bankName: String) -> DictionaryValidationResult {
        let normalizedBank = bankName.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let exactMatch = bankNames.first { normalizedBank.contains($0) || $0.contains(normalizedBank) }
        
        if let match = exactMatch {
            return DictionaryValidationResult(
                isValid: true,
                confidence: 0.9,
                suggestions: [match],
                matchType: .exact
            )
        }
        
        return DictionaryValidationResult(
            isValid: false,
            confidence: 0.5,
            suggestions: [],
            matchType: .none
        )
    }
}

class FinancialPatternValidator {
    func validateAmount(_ amount: String) -> Bool {
        let pattern = "^[0-9,]+(?:\\.[0-9]{1,2})?$"
        return amount.range(of: pattern, options: .regularExpression) != nil
    }
    
    func validatePercentage(_ percentage: String) -> Bool {
        let pattern = "^[0-9]+(?:\\.[0-9]{1,2})?%?$"
        return percentage.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Data Structures

struct PayslipContext {
    let surroundingText: [String]
    let documentType: String
    let expectedFields: [MilitaryPayslipFieldType]
}

struct FieldContext {
    let fieldType: MilitaryPayslipFieldType
    let surroundingText: [String]
    let expectedPattern: String?
    let position: CGRect
}

struct CorrectionResult {
    let originalText: String
    let correctedText: String
    let confidenceBoost: Float
    let corrections: [String]
    let wasModified: Bool
}

struct DictionaryValidationResult {
    let isValid: Bool
    let confidence: Float
    let suggestions: [String]
    let matchType: MatchType
}

enum MatchType {
    case exact
    case partial
    case fuzzy
    case none
} 