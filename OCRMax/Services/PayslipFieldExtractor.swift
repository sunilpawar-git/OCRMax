//
//  PayslipFieldExtractor.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import UIKit

protocol PayslipFieldExtractorProtocol {
    func extractMilitaryPayslip(from structureAnalysis: PayslipStructureAnalysis, using template: PayslipTemplate) async throws -> MilitaryPayslip
    func extractFieldsByCategory(from fields: [MilitaryPayslipField]) -> [FieldCategory: [MilitaryPayslipField]]
    func validateAndCorrectFields(_ fields: [MilitaryPayslipField]) -> [MilitaryPayslipField]
}

final class PayslipFieldExtractor: PayslipFieldExtractorProtocol {
    
    private let templateEngine: PayslipTemplateEngine
    private let dateFormatter: DateFormatter
    
    init(templateEngine: PayslipTemplateEngine = PayslipTemplateEngine()) {
        self.templateEngine = templateEngine
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "dd/MM/yyyy"
    }
    
    enum ExtractionError: LocalizedError {
        case insufficientFields
        case parsingFailed(String)
        case validationFailed
        case templateMismatch
        
        var errorDescription: String? {
            switch self {
            case .insufficientFields:
                return "Insufficient fields extracted for payslip creation"
            case .parsingFailed(let reason):
                return "Payslip parsing failed: \(reason)"
            case .validationFailed:
                return "Field validation failed"
            case .templateMismatch:
                return "Template does not match extracted fields"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func extractMilitaryPayslip(from structureAnalysis: PayslipStructureAnalysis, using template: PayslipTemplate) async throws -> MilitaryPayslip {
        
        let startTime = Date()
        
        // Extract fields using the template
        let extractedFields = try await templateEngine.extractFields(using: template, from: structureAnalysis)
        
        // Validate and correct fields
        let correctedFields = validateAndCorrectFields(extractedFields)
        
        // Validate against template
        let validationResult = templateEngine.validateExtractedFields(correctedFields, template: template)
        
        guard validationResult.score >= 0.6 else {
            throw ExtractionError.validationFailed
        }
        
        // Organize fields by category
        let fieldsByCategory = extractFieldsByCategory(from: correctedFields)
        
        // Extract structured components
        let employeeInfo = try extractEmployeeInfo(from: fieldsByCategory[.employeeInfo] ?? [])
        let payDetails = try extractPayDetails(from: fieldsByCategory[.payDetails] ?? [], allowances: fieldsByCategory[.allowances] ?? [], deductions: fieldsByCategory[.deductions] ?? [])
        let allowances = extractAllowances(from: fieldsByCategory[.allowances] ?? [])
        let deductions = extractDeductions(from: fieldsByCategory[.deductions] ?? [])
        let netPay = extractNetPayInfo(from: payDetails, fields: correctedFields)
        let bankDetails = extractBankDetails(from: fieldsByCategory[.bankDetails] ?? [])
        let period = extractPayPeriod(from: fieldsByCategory[.payPeriod] ?? [])
        
        // Calculate overall confidence
        let overallConfidence = correctedFields.map { $0.confidence }.reduce(0, +) / Float(max(correctedFields.count, 1))
        
        // Create extraction metadata
        let processingTime = Date().timeIntervalSince(startTime)
        let metadata = ExtractionMetadata(
            extractionDate: Date(),
            templateUsed: template.id,
            confidence: overallConfidence,
            processingTime: processingTime,
            validationScore: validationResult.score
        )
        
        return MilitaryPayslip(
            employeeInfo: employeeInfo,
            payDetails: payDetails,
            allowances: allowances,
            deductions: deductions,
            netPay: netPay,
            bankDetails: bankDetails,
            period: period,
            confidence: overallConfidence,
            extractionMetadata: metadata
        )
    }
    
    func extractFieldsByCategory(from fields: [MilitaryPayslipField]) -> [FieldCategory: [MilitaryPayslipField]] {
        return Dictionary(grouping: fields) { $0.type.category }
    }
    
    func validateAndCorrectFields(_ fields: [MilitaryPayslipField]) -> [MilitaryPayslipField] {
        return fields.compactMap { field in
            var correctedField = field
            
            // Apply field-specific corrections
            switch field.type {
            case .employeeId:
                correctedField = correctEmployeeId(field)
            case .employeeName:
                correctedField = correctEmployeeName(field)
            case .basicPay, .gradePay, .totalEarnings, .totalDeductions, .netPay:
                correctedField = correctNumericField(field)
            case .panNumber:
                correctedField = correctPANNumber(field)
            case .accountNumber:
                correctedField = correctAccountNumber(field)
            case .payPeriod:
                correctedField = correctPayPeriod(field)
            default:
                correctedField = correctGenericField(field)
            }
            
            // Only return fields that pass minimum validation
            return correctedField.confidence >= 0.3 ? correctedField : nil
        }
    }
    
    // MARK: - Private Extraction Methods
    
    private func extractEmployeeInfo(from fields: [MilitaryPayslipField]) throws -> EmployeeInfo {
        guard let employeeIdField = fields.first(where: { $0.type == .employeeId }),
              let nameField = fields.first(where: { $0.type == .employeeName }) else {
            throw ExtractionError.insufficientFields
        }
        
        return EmployeeInfo(
            employeeId: employeeIdField.value,
            name: nameField.value,
            designation: fields.first(where: { $0.type == .designation })?.value,
            department: fields.first(where: { $0.type == .department })?.value,
            payLevel: fields.first(where: { $0.type == .payLevel })?.value,
            panNumber: fields.first(where: { $0.type == .panNumber })?.value,
            serviceNumber: fields.first(where: { $0.type == .serviceNumber })?.value
        )
    }
    
    private func extractPayDetails(from payFields: [MilitaryPayslipField], allowances: [MilitaryPayslipField], deductions: [MilitaryPayslipField]) throws -> PayDetails {
        guard let basicPayField = payFields.first(where: { $0.type == .basicPay }),
              let netPayField = payFields.first(where: { $0.type == .netPay }) else {
            throw ExtractionError.insufficientFields
        }
        
        let basicPay = parseNumericValue(basicPayField.value) ?? 0.0
        let gradePay = payFields.first(where: { $0.type == .gradePay }).flatMap { parseNumericValue($0.value) }
        let netPay = parseNumericValue(netPayField.value) ?? 0.0
        
        // Calculate totals from individual items if not directly available
        var totalEarnings = payFields.first(where: { $0.type == .totalEarnings }).flatMap { parseNumericValue($0.value) }
        var totalDeductions = payFields.first(where: { $0.type == .totalDeductions }).flatMap { parseNumericValue($0.value) }
        
        if totalEarnings == nil {
            totalEarnings = basicPay + (gradePay ?? 0) + allowances.compactMap { parseNumericValue($0.value) }.reduce(0, +)
        }
        
        if totalDeductions == nil {
            totalDeductions = deductions.compactMap { parseNumericValue($0.value) }.reduce(0, +)
        }
        
        return PayDetails(
            basicPay: basicPay,
            gradePay: gradePay,
            totalEarnings: totalEarnings ?? basicPay,
            totalDeductions: totalDeductions ?? 0.0,
            netPay: netPay
        )
    }
    
    private func extractAllowances(from fields: [MilitaryPayslipField]) -> [Allowance] {
        return fields.compactMap { field in
            guard let amount = parseNumericValue(field.value) else { return nil }
            
            let allowanceType = mapToAllowanceType(field.type)
            return Allowance(
                type: allowanceType,
                description: field.label,
                amount: amount,
                isFixed: isFixedAllowance(allowanceType)
            )
        }
    }
    
    private func extractDeductions(from fields: [MilitaryPayslipField]) -> [Deduction] {
        return fields.compactMap { field in
            guard let amount = parseNumericValue(field.value) else { return nil }
            
            let deductionType = mapToDeductionType(field.type)
            return Deduction(
                type: deductionType,
                description: field.label,
                amount: amount,
                isStatutory: isStatutoryDeduction(deductionType)
            )
        }
    }
    
    private func extractNetPayInfo(from payDetails: PayDetails, fields: [MilitaryPayslipField]) -> NetPayInfo {
        return NetPayInfo(
            grossPay: payDetails.totalEarnings,
            totalDeductions: payDetails.totalDeductions,
            netAmount: payDetails.netPay,
            amountInWords: nil // Could be extracted if present in the document
        )
    }
    
    private func extractBankDetails(from fields: [MilitaryPayslipField]) -> BankInfo {
        return BankInfo(
            bankName: fields.first(where: { $0.type == .bankName })?.value,
            accountNumber: fields.first(where: { $0.type == .accountNumber })?.value,
            branchCode: fields.first(where: { $0.type == .branchCode })?.value,
            ifscCode: fields.first(where: { $0.type == .ifscCode })?.value
        )
    }
    
    private func extractPayPeriod(from fields: [MilitaryPayslipField]) -> PayPeriod {
        let payPeriodField = fields.first(where: { $0.type == .payPeriod })
        let payMonthField = fields.first(where: { $0.type == .payMonth })
        let payYearField = fields.first(where: { $0.type == .payYear })
        
        var startDate: Date?
        var endDate: Date?
        var payMonth = payMonthField?.value ?? ""
        var payYear = payYearField?.value ?? ""
        
        // Parse pay period if available
        if let periodText = payPeriodField?.value {
            let components = periodText.components(separatedBy: "/")
            if components.count >= 2 {
                payMonth = components[0]
                payYear = components[1]
            }
            
            // Try to extract dates
            if let date = dateFormatter.date(from: periodText) {
                endDate = date
                startDate = Calendar.current.date(byAdding: .month, value: -1, to: date)
            }
        }
        
        return PayPeriod(
            startDate: startDate,
            endDate: endDate,
            payMonth: payMonth,
            payYear: payYear
        )
    }
    
    // MARK: - Field Correction Methods
    
    private func correctEmployeeId(_ field: MilitaryPayslipField) -> MilitaryPayslipField {
        // Remove any non-numeric characters
        let correctedValue = field.value.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Boost confidence if it looks like a valid employee ID
        let newConfidence = correctedValue.count >= 5 && correctedValue.count <= 8 ? 
            min(field.confidence + 0.1, 1.0) : field.confidence
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctedValue,
            confidence: newConfidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    private func correctEmployeeName(_ field: MilitaryPayslipField) -> MilitaryPayslipField {
        // Clean up name formatting
        var correctedValue = field.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .uppercased()
        
        // Remove common prefixes/suffixes that might be OCR artifacts
        let prefixesToRemove = ["MR.", "MRS.", "MS.", "DR."]
        for prefix in prefixesToRemove {
            if correctedValue.hasPrefix(prefix) {
                correctedValue = String(correctedValue.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctedValue,
            confidence: field.confidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    private func correctNumericField(_ field: MilitaryPayslipField) -> MilitaryPayslipField {
        // Clean numeric value
        var correctedValue = field.value
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "Rs.", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[^0-9,.]", with: "", options: .regularExpression)
        
        // Validate numeric format
        let newConfidence: Float
        if parseNumericValue(correctedValue) != nil {
            newConfidence = min(field.confidence + 0.1, 1.0)
        } else {
            newConfidence = max(field.confidence - 0.2, 0.0)
        }
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctedValue,
            confidence: newConfidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    private func correctPANNumber(_ field: MilitaryPayslipField) -> MilitaryPayslipField {
        // PAN format: ABCDE1234F
        let correctedValue = field.value
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        
        // Validate PAN format
        let panPattern = "^[A-Z]{5}[0-9]{4}[A-Z]$"
        let newConfidence: Float
        if correctedValue.range(of: panPattern, options: .regularExpression) != nil {
            newConfidence = min(field.confidence + 0.2, 1.0)
        } else {
            newConfidence = max(field.confidence - 0.3, 0.0)
        }
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctedValue,
            confidence: newConfidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    private func correctAccountNumber(_ field: MilitaryPayslipField) -> MilitaryPayslipField {
        // Remove spaces and non-numeric characters for account numbers
        let correctedValue = field.value
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Bank account numbers are typically 9-18 digits
        let newConfidence: Float
        if correctedValue.count >= 9 && correctedValue.count <= 18 {
            newConfidence = min(field.confidence + 0.1, 1.0)
        } else {
            newConfidence = max(field.confidence - 0.2, 0.0)
        }
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctedValue,
            confidence: newConfidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    private func correctPayPeriod(_ field: MilitaryPayslipField) -> MilitaryPayslipField {
        // Try to standardize date format
        var correctedValue = field.value
            .replacingOccurrences(of: " ", with: "")
        
        // Common date patterns in payslips
        let datePatterns = [
            ("(\\d{2})/(\\d{4})", "$1/$2"),  // MM/YYYY
            ("(\\d{1,2})-(\\d{4})", "$1/$2"), // M-YYYY or MM-YYYY
            ("(\\d{2})(\\d{4})", "$1/$2")     // MMYYYY
        ]
        
        for (pattern, replacement) in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(correctedValue.startIndex..., in: correctedValue)
                correctedValue = regex.stringByReplacingMatches(
                    in: correctedValue,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
                break
            }
        }
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctedValue,
            confidence: field.confidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    private func correctGenericField(_ field: MilitaryPayslipField) -> MilitaryPayslipField {
        // Basic cleanup for generic fields
        let correctedValue = field.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return MilitaryPayslipField(
            type: field.type,
            label: field.label,
            value: correctedValue,
            confidence: field.confidence,
            source: field.source,
            isRequired: field.isRequired
        )
    }
    
    // MARK: - Helper Methods
    
    private func parseNumericValue(_ value: String) -> Double? {
        let cleanedValue = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        return Double(cleanedValue)
    }
    
    private func mapToAllowanceType(_ fieldType: MilitaryPayslipFieldType) -> AllowanceType {
        switch fieldType {
        case .da:
            return .dearnesAllowance
        case .hra:
            return .houseRentAllowance
        case .transportAllowance:
            return .transportAllowance
        case .medicalAllowance:
            return .medicalAllowance
        default:
            return .other
        }
    }
    
    private func mapToDeductionType(_ fieldType: MilitaryPayslipFieldType) -> DeductionType {
        switch fieldType {
        case .providentFund:
            return .providentFund
        case .incomeTax:
            return .incomeTax
        case .lifeInsurance:
            return .lifeInsurance
        default:
            return .other
        }
    }
    
    private func isFixedAllowance(_ type: AllowanceType) -> Bool {
        switch type {
        case .dearnesAllowance, .houseRentAllowance:
            return false // Usually percentage-based
        case .transportAllowance, .medicalAllowance:
            return true  // Usually fixed amounts
        default:
            return false
        }
    }
    
    private func isStatutoryDeduction(_ type: DeductionType) -> Bool {
        switch type {
        case .providentFund, .incomeTax, .professionalTax:
            return true
        case .lifeInsurance, .loan, .advance, .canteenCharges:
            return false
        default:
            return false
        }
    }
} 