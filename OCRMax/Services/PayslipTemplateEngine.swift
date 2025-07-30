//
//  PayslipTemplateEngine.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import UIKit

protocol PayslipTemplateEngineProtocol {
    func identifyPayslipTemplate(from structureAnalysis: PayslipStructureAnalysis) async throws -> PayslipTemplate
    func extractFields(using template: PayslipTemplate, from structureAnalysis: PayslipStructureAnalysis) async throws -> [MilitaryPayslipField]
    func validateExtractedFields(_ fields: [MilitaryPayslipField], template: PayslipTemplate) -> FieldValidationResult
}

final class PayslipTemplateEngine: PayslipTemplateEngineProtocol {
    
    private let supportedTemplates: [PayslipTemplate]
    
    init() {
        self.supportedTemplates = PayslipTemplate.getAllTemplates()
    }
    
    enum TemplateError: LocalizedError {
        case noMatchingTemplate
        case fieldExtractionFailed(String)
        case templateValidationFailed
        case insufficientData
        
        var errorDescription: String? {
            switch self {
            case .noMatchingTemplate:
                return "No matching payslip template found"
            case .fieldExtractionFailed(let reason):
                return "Field extraction failed: \(reason)"
            case .templateValidationFailed:
                return "Template validation failed"
            case .insufficientData:
                return "Insufficient data for template matching"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func identifyPayslipTemplate(from structureAnalysis: PayslipStructureAnalysis) async throws -> PayslipTemplate {
        guard !structureAnalysis.keyFields.isEmpty else {
            throw TemplateError.insufficientData
        }
        
        var templateScores: [(PayslipTemplate, Float)] = []
        
        for template in supportedTemplates {
            let score = calculateTemplateMatchScore(
                template: template,
                structureAnalysis: structureAnalysis
            )
            templateScores.append((template, score))
        }
        
        // Sort by score descending
        templateScores.sort { $0.1 > $1.1 }
        
        guard let bestMatch = templateScores.first,
              bestMatch.1 >= 0.6 else {
            throw TemplateError.noMatchingTemplate
        }
        
        return bestMatch.0
    }
    
    func extractFields(using template: PayslipTemplate, from structureAnalysis: PayslipStructureAnalysis) async throws -> [MilitaryPayslipField] {
        var extractedFields: [MilitaryPayslipField] = []
        
        for fieldTemplate in template.fieldTemplates {
            if let field = try await extractField(
                fieldTemplate: fieldTemplate,
                from: structureAnalysis
            ) {
                extractedFields.append(field)
            }
        }
        
        // Ensure mandatory fields are present
        let mandatoryFieldTypes = template.mandatoryFields
        let extractedFieldTypes = Set(extractedFields.map { $0.type })
        let missingFields = mandatoryFieldTypes.subtracting(extractedFieldTypes)
        
        if !missingFields.isEmpty {
            throw TemplateError.fieldExtractionFailed("Missing mandatory fields: \(missingFields)")
        }
        
        return extractedFields
    }
    
    func validateExtractedFields(_ fields: [MilitaryPayslipField], template: PayslipTemplate) -> FieldValidationResult {
        var validationIssues: [FieldValidationIssue] = []
        var validFieldCount = 0
        let totalFieldCount = fields.count
        
        for field in fields {
            let fieldValidation = validateIndividualField(field, template: template)
            if !fieldValidation.isValid {
                validationIssues.append(contentsOf: fieldValidation.issues)
            } else {
                validFieldCount += 1
            }
        }
        
        // Cross-field validation
        let crossValidationIssues = performCrossFieldValidation(fields, template: template)
        validationIssues.append(contentsOf: crossValidationIssues)
        
        let validationScore = totalFieldCount > 0 ? Float(validFieldCount) / Float(totalFieldCount) : 0.0
        
        return FieldValidationResult(
            isValid: validationIssues.isEmpty,
            score: validationScore,
            issues: validationIssues,
            validatedFieldCount: validFieldCount,
            totalFieldCount: totalFieldCount
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateTemplateMatchScore(template: PayslipTemplate, structureAnalysis: PayslipStructureAnalysis) -> Float {
        var score: Float = 0.0
        var totalChecks: Float = 0.0
        
        // Check for presence of signature fields
        for signatureField in template.signatureFields {
            totalChecks += 1
            // Convert MilitaryPayslipFieldType to PayslipFieldType for comparison
            if let matchingField = convertToPayslipFieldType(signatureField),
               structureAnalysis.keyFields.contains(where: { $0.type == matchingField }) {
                score += 1.0
            }
        }
        
        // Check table structure compatibility
        totalChecks += 1
        if isTableStructureCompatible(template: template, structureAnalysis: structureAnalysis) {
            score += 1.0
        }
        
        // Check section presence
        for requiredSection in template.requiredSections {
            totalChecks += 1
            if structureAnalysis.payslipSections.section(for: requiredSection) != nil {
                score += 1.0
            }
        }
        
        // Check field patterns
        totalChecks += 1
        let patternMatchScore = calculatePatternMatchScore(template: template, structureAnalysis: structureAnalysis)
        score += patternMatchScore
        
        return totalChecks > 0 ? score / totalChecks : 0.0
    }
    
    private func isTableStructureCompatible(template: PayslipTemplate, structureAnalysis: PayslipStructureAnalysis) -> Bool {
        guard let gridStructure = structureAnalysis.layoutAnalysis.gridStructure else {
            return false
        }
        
        return gridStructure.dimensions.columns >= template.minimumColumns &&
               gridStructure.dimensions.rows >= template.minimumRows &&
               gridStructure.hasHeader == template.requiresHeader
    }
    
    private func calculatePatternMatchScore(template: PayslipTemplate, structureAnalysis: PayslipStructureAnalysis) -> Float {
        let allText = structureAnalysis.parsedTable.rows.flatMap { row in
            row.cells.flatMap { cell in
                cell.textBlocks.map { $0.text }
            }
        }.joined(separator: " ")
        
        var matchCount = 0
        let totalPatterns = template.identificationPatterns.count
        
        for pattern in template.identificationPatterns {
            if allText.range(of: pattern, options: .regularExpression) != nil {
                matchCount += 1
            }
        }
        
        return totalPatterns > 0 ? Float(matchCount) / Float(totalPatterns) : 0.0
    }
    
    private func extractField(fieldTemplate: FieldTemplate, from structureAnalysis: PayslipStructureAnalysis) async throws -> MilitaryPayslipField? {
        
        // Try different extraction strategies based on field type
        switch fieldTemplate.extractionStrategy {
        case .patternBased:
            return extractFieldByPattern(fieldTemplate: fieldTemplate, from: structureAnalysis)
        case .sectionBased:
            return extractFieldBySection(fieldTemplate: fieldTemplate, from: structureAnalysis)
        case .positionBased:
            return extractFieldByPosition(fieldTemplate: fieldTemplate, from: structureAnalysis)
        case .tableBased:
            return extractFieldFromTable(fieldTemplate: fieldTemplate, from: structureAnalysis)
        }
    }
    
    private func extractFieldByPattern(fieldTemplate: FieldTemplate, from structureAnalysis: PayslipStructureAnalysis) -> MilitaryPayslipField? {
        let allTextBlocks = structureAnalysis.parsedTable.rows.flatMap { row in
            row.cells.flatMap { cell in
                cell.textBlocks
            }
        }
        
        for pattern in fieldTemplate.patterns {
            for textBlock in allTextBlocks {
                if let field = extractFieldWithPattern(
                    pattern: pattern,
                    text: textBlock.text,
                    fieldType: fieldTemplate.fieldType,
                    confidence: textBlock.confidence
                ) {
                    return field
                }
            }
        }
        
        return nil
    }
    
    private func extractFieldBySection(fieldTemplate: FieldTemplate, from structureAnalysis: PayslipStructureAnalysis) -> MilitaryPayslipField? {
        guard let targetSection = fieldTemplate.targetSection,
              let section = structureAnalysis.payslipSections.section(for: targetSection) else {
            return nil
        }
        
        let sectionText = section.textBlocks.map { $0.text }.joined(separator: " ")
        
        for pattern in fieldTemplate.patterns {
            if let field = extractFieldWithPattern(
                pattern: pattern,
                text: sectionText,
                fieldType: fieldTemplate.fieldType,
                confidence: section.confidence
            ) {
                return field
            }
        }
        
        return nil
    }
    
    private func extractFieldByPosition(fieldTemplate: FieldTemplate, from structureAnalysis: PayslipStructureAnalysis) -> MilitaryPayslipField? {
        guard let position = fieldTemplate.expectedPosition else {
            return nil
        }
        
        // Find text blocks in the expected position
        let textBlocks = structureAnalysis.parsedTable.rows.flatMap { row in
            row.cells.flatMap { cell in
                cell.textBlocks.filter { textBlock in
                    position.bounds.intersects(textBlock.boundingBox)
                }
            }
        }
        
        let combinedText = textBlocks.map { $0.text }.joined(separator: " ")
        let averageConfidence = textBlocks.isEmpty ? 0.0 : textBlocks.map { $0.confidence }.reduce(0, +) / Float(textBlocks.count)
        
        for pattern in fieldTemplate.patterns {
            if let field = extractFieldWithPattern(
                pattern: pattern,
                text: combinedText,
                fieldType: fieldTemplate.fieldType,
                confidence: averageConfidence
            ) {
                return field
            }
        }
        
        return nil
    }
    
    private func extractFieldFromTable(fieldTemplate: FieldTemplate, from structureAnalysis: PayslipStructureAnalysis) -> MilitaryPayslipField? {
        guard let labelPattern = fieldTemplate.labelPattern else {
            return nil
        }
        
        // Find the label cell first
        for row in structureAnalysis.parsedTable.rows {
            for (index, cell) in row.cells.enumerated() {
                let cellText = cell.textBlocks.map { $0.text }.joined(separator: " ")
                
                if cellText.range(of: labelPattern, options: .regularExpression) != nil {
                    // Found label, look for value in adjacent cells
                    let valueCell = findValueCell(for: index, in: row, fieldTemplate: fieldTemplate)
                    
                    if let valueCell = valueCell {
                        let valueText = valueCell.textBlocks.map { $0.text }.joined(separator: " ")
                        
                        return MilitaryPayslipField(
                            type: fieldTemplate.fieldType,
                            label: cellText.trimmingCharacters(in: .whitespacesAndNewlines),
                            value: valueText.trimmingCharacters(in: .whitespacesAndNewlines),
                            confidence: (cell.confidence + valueCell.confidence) / 2,
                            source: .tableExtraction,
                            isRequired: fieldTemplate.isRequired
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractFieldWithPattern(pattern: String, text: String, fieldType: MilitaryPayslipFieldType, confidence: Float) -> MilitaryPayslipField? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let matchedText: String
        if match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: text) {
            matchedText = String(text[range])
        } else {
            matchedText = String(text[Range(match.range, in: text)!])
        }
        
        return MilitaryPayslipField(
            type: fieldType,
            label: fieldType.defaultLabel,
            value: matchedText.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: confidence,
            source: .patternMatching,
            isRequired: fieldType.isRequired
        )
    }
    
    private func findValueCell(for labelIndex: Int, in row: TableRow, fieldTemplate: FieldTemplate) -> TableCellAnalysis? {
        // Look for value in the next cell (most common case)
        if labelIndex + 1 < row.cells.count {
            return row.cells[labelIndex + 1]
        }
        
        // Look for value in the previous cell (less common)
        if labelIndex > 0 {
            return row.cells[labelIndex - 1]
        }
        
        return nil
    }
    
    private func validateIndividualField(_ field: MilitaryPayslipField, template: PayslipTemplate) -> SingleFieldValidationResult {
        var issues: [FieldValidationIssue] = []
        
        // Check if field value matches expected format
        if let fieldTemplate = template.fieldTemplates.first(where: { $0.fieldType == field.type }) {
            for validationPattern in fieldTemplate.validationPatterns {
                if field.value.range(of: validationPattern, options: .regularExpression) == nil {
                    issues.append(.invalidFormat(field.type, expected: validationPattern, actual: field.value))
                }
            }
            
            // Check value length constraints
            if let minLength = fieldTemplate.minLength, field.value.count < minLength {
                issues.append(.valueTooShort(field.type, minLength: minLength, actualLength: field.value.count))
            }
            
            if let maxLength = fieldTemplate.maxLength, field.value.count > maxLength {
                issues.append(.valueTooLong(field.type, maxLength: maxLength, actualLength: field.value.count))
            }
        }
        
        // Check confidence threshold
        if field.confidence < 0.5 {
            issues.append(.lowConfidence(field.type, confidence: field.confidence))
        }
        
        return SingleFieldValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    private func performCrossFieldValidation(_ fields: [MilitaryPayslipField], template: PayslipTemplate) -> [FieldValidationIssue] {
        var issues: [FieldValidationIssue] = []
        
        // Validate financial calculations
        issues.append(contentsOf: validateFinancialCalculations(fields))
        
        // Validate date consistency
        issues.append(contentsOf: validateDateConsistency(fields))
        
        // Validate field relationships
        issues.append(contentsOf: validateFieldRelationships(fields, template: template))
        
        return issues
    }
    
    private func validateFinancialCalculations(_ fields: [MilitaryPayslipField]) -> [FieldValidationIssue] {
        var issues: [FieldValidationIssue] = []
        
        // Extract financial values
        let _ = extractNumericValue(from: fields, type: .basicPay)
        let totalEarnings = extractNumericValue(from: fields, type: .totalEarnings)
        let totalDeductions = extractNumericValue(from: fields, type: .totalDeductions)
        let netPay = extractNumericValue(from: fields, type: .netPay)
        
        // Validate calculations
        if let totalEarnings = totalEarnings,
           let totalDeductions = totalDeductions,
           let netPay = netPay {
            
            let calculatedNet = totalEarnings - totalDeductions
            let difference = abs(calculatedNet - netPay)
            
            if difference > 1.0 { // Allow for rounding differences
                issues.append(.calculationMismatch(
                    expected: calculatedNet,
                    actual: netPay,
                    field: .netPay
                ))
            }
        }
        
        return issues
    }
    
    private func validateDateConsistency(_ fields: [MilitaryPayslipField]) -> [FieldValidationIssue] {
        // For now, just check if dates are reasonable
        // Could be extended to check date ranges, sequences, etc.
        return []
    }
    
    private func validateFieldRelationships(_ fields: [MilitaryPayslipField], template: PayslipTemplate) -> [FieldValidationIssue] {
        // Validate relationships defined in the template
        return []
    }
    
    private func extractNumericValue(from fields: [MilitaryPayslipField], type: MilitaryPayslipFieldType) -> Double? {
        guard let field = fields.first(where: { $0.type == type }) else {
            return nil
        }
        
        // Remove currency symbols and formatting
        let cleanedValue = field.value
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Double(cleanedValue)
    }
    
    private func convertToPayslipFieldType(_ militaryFieldType: MilitaryPayslipFieldType) -> PayslipFieldType? {
        switch militaryFieldType {
        case .employeeId:
            return .employeeId
        case .employeeName:
            return .employeeName
        case .panNumber:
            return .pan
        case .netPay:
            return .netAmount
        case .payPeriod:
            return .payPeriod
        // Add more mappings as needed
        default:
            return nil
        }
    }
}

// MARK: - Supporting Data Structures

struct SingleFieldValidationResult {
    let isValid: Bool
    let issues: [FieldValidationIssue]
}

struct FieldValidationResult {
    let isValid: Bool
    let score: Float
    let issues: [FieldValidationIssue]
    let validatedFieldCount: Int
    let totalFieldCount: Int
}

enum FieldValidationIssue {
    case invalidFormat(MilitaryPayslipFieldType, expected: String, actual: String)
    case valueTooShort(MilitaryPayslipFieldType, minLength: Int, actualLength: Int)
    case valueTooLong(MilitaryPayslipFieldType, maxLength: Int, actualLength: Int)
    case lowConfidence(MilitaryPayslipFieldType, confidence: Float)
    case calculationMismatch(expected: Double, actual: Double, field: MilitaryPayslipFieldType)
    case missingMandatoryField(MilitaryPayslipFieldType)
    case inconsistentDates(field1: MilitaryPayslipFieldType, field2: MilitaryPayslipFieldType)
} 