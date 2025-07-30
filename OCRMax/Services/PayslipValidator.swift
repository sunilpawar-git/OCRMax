//
//  PayslipValidator.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import UIKit

protocol PayslipValidatorProtocol {
    func validateMilitaryPayslip(_ payslip: MilitaryPayslip, template: PayslipTemplate) async throws -> PayslipValidationReport
    func performFinancialValidation(_ payslip: MilitaryPayslip) -> [ValidationIssue]
    func validateDataConsistency(_ payslip: MilitaryPayslip) -> [ValidationIssue]
    func suggestCorrections(for issues: [ValidationIssue], payslip: MilitaryPayslip) -> [CorrectionSuggestion]
}

final class PayslipValidator: PayslipValidatorProtocol {
    
    private let toleranceAmount: Double = 2.0 // Allow ₹2 tolerance for rounding
    private let confidenceThreshold: Float = 0.6
    
    enum ValidationError: LocalizedError {
        case criticalValidationFailure
        case insufficientData
        case financialInconsistency
        
        var errorDescription: String? {
            switch self {
            case .criticalValidationFailure:
                return "Critical validation failures detected"
            case .insufficientData:
                return "Insufficient data for validation"
            case .financialInconsistency:
                return "Financial data inconsistency detected"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func validateMilitaryPayslip(_ payslip: MilitaryPayslip, template: PayslipTemplate) async throws -> PayslipValidationReport {
        var allIssues: [ValidationIssue] = []
        
        // 1. Basic data validation
        let basicIssues = validateBasicData(payslip)
        allIssues.append(contentsOf: basicIssues)
        
        // 2. Financial validation
        let financialIssues = performFinancialValidation(payslip)
        allIssues.append(contentsOf: financialIssues)
        
        // 3. Data consistency validation
        let consistencyIssues = validateDataConsistency(payslip)
        allIssues.append(contentsOf: consistencyIssues)
        
        // 4. Template compliance validation
        let templateIssues = validateTemplateCompliance(payslip, template: template)
        allIssues.append(contentsOf: templateIssues)
        
        // 5. Range validation
        let rangeIssues = validateRanges(payslip)
        allIssues.append(contentsOf: rangeIssues)
        
        // 6. Date validation
        let dateIssues = validateDates(payslip)
        allIssues.append(contentsOf: dateIssues)
        
        // 7. Generate correction suggestions
        let suggestions = suggestCorrections(for: allIssues, payslip: payslip)
        
        // 8. Calculate validation score
        let score = calculateValidationScore(issues: allIssues, payslip: payslip)
        
        // 9. Determine severity
        let severity = determineSeverity(issues: allIssues)
        
        return PayslipValidationReport(
            isValid: allIssues.filter { $0.severity == .critical }.isEmpty,
            score: score,
            issues: allIssues,
            suggestions: suggestions,
            severity: severity,
            validatedAt: Date(),
            payslipConfidence: payslip.confidence,
            templateUsed: payslip.extractionMetadata.templateUsed
        )
    }
    
    func performFinancialValidation(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate basic pay calculation
        issues.append(contentsOf: validateBasicPayCalculation(payslip))
        
        // Validate total earnings
        issues.append(contentsOf: validateTotalEarnings(payslip))
        
        // Validate total deductions
        issues.append(contentsOf: validateTotalDeductions(payslip))
        
        // Validate net pay calculation
        issues.append(contentsOf: validateNetPayCalculation(payslip))
        
        // Validate allowance calculations
        issues.append(contentsOf: validateAllowanceCalculations(payslip))
        
        // Validate deduction calculations
        issues.append(contentsOf: validateDeductionCalculations(payslip))
        
        return issues
    }
    
    func validateDataConsistency(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Employee information consistency
        issues.append(contentsOf: validateEmployeeInfoConsistency(payslip))
        
        // Bank details consistency
        issues.append(contentsOf: validateBankDetailsConsistency(payslip))
        
        // Pay period consistency
        issues.append(contentsOf: validatePayPeriodConsistency(payslip))
        
        // Cross-reference validation
        issues.append(contentsOf: validateCrossReferences(payslip))
        
        return issues
    }
    
    func suggestCorrections(for issues: [ValidationIssue], payslip: MilitaryPayslip) -> [CorrectionSuggestion] {
        var suggestions: [CorrectionSuggestion] = []
        
        for issue in issues {
            switch issue.type {
            case .financialMismatch(let expected, let actual, _):
                suggestions.append(CorrectionSuggestion(
                    issueType: issue.type,
                    suggestedValue: String(expected),
                    currentValue: String(actual),
                    confidence: 0.9,
                    reasoning: "Financial calculation suggests value should be \(expected)",
                    autoCorrectible: true
                ))
                
            case .invalidFormat(_, let expected, let actual):
                let correctedValue = attemptFormatCorrection(actual, expectedFormat: expected)
                if let corrected = correctedValue {
                    suggestions.append(CorrectionSuggestion(
                        issueType: issue.type,
                        suggestedValue: corrected,
                        currentValue: actual,
                        confidence: 0.8,
                        reasoning: "Format correction based on expected pattern",
                        autoCorrectible: true
                    ))
                }
                
            case .outOfRange(_, let value, let range):
                let suggestedValue = clampToRange(value, range: range)
                suggestions.append(CorrectionSuggestion(
                    issueType: issue.type,
                    suggestedValue: String(suggestedValue),
                    currentValue: String(value),
                    confidence: 0.7,
                    reasoning: "Value clamped to acceptable range",
                    autoCorrectible: false
                ))
                
            case .lowConfidence(_, let confidence):
                suggestions.append(CorrectionSuggestion(
                    issueType: issue.type,
                    suggestedValue: "Manual review required",
                    currentValue: "Confidence: \(confidence)",
                    confidence: 0.5,
                    reasoning: "Low confidence field requires manual verification",
                    autoCorrectible: false
                ))
                
            default:
                // Generic suggestion for other issue types
                suggestions.append(CorrectionSuggestion(
                    issueType: issue.type,
                    suggestedValue: "Review required",
                    currentValue: "N/A",
                    confidence: 0.6,
                    reasoning: "Manual review recommended for this issue",
                    autoCorrectible: false
                ))
            }
        }
        
        return suggestions
    }
    
    // MARK: - Private Validation Methods
    
    private func validateBasicData(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Employee ID validation
        if payslip.employeeInfo.employeeId.isEmpty {
            issues.append(ValidationIssue(
                type: .missingRequiredField(.employeeId),
                severity: .critical,
                message: "Employee ID is required",
                field: "employeeId"
            ))
        } else if !isValidEmployeeId(payslip.employeeInfo.employeeId) {
            issues.append(ValidationIssue(
                type: .invalidFormat(.employeeId, expected: "5-8 digits", actual: payslip.employeeInfo.employeeId),
                severity: .warning,
                message: "Employee ID format appears invalid",
                field: "employeeId"
            ))
        }
        
        // Employee name validation
        if payslip.employeeInfo.name.isEmpty {
            issues.append(ValidationIssue(
                type: .missingRequiredField(.employeeName),
                severity: .critical,
                message: "Employee name is required",
                field: "employeeName"
            ))
        }
        
        // PAN validation
        if let pan = payslip.employeeInfo.panNumber, !pan.isEmpty {
            if !isValidPAN(pan) {
                issues.append(ValidationIssue(
                    type: .invalidFormat(.panNumber, expected: "ABCDE1234F", actual: pan),
                    severity: .error,
                    message: "PAN number format is invalid",
                    field: "panNumber"
                ))
            }
        }
        
        return issues
    }
    
    private func validateBasicPayCalculation(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        let basicPay = payslip.payDetails.basicPay
        
        // Basic pay should be reasonable for military personnel
        if basicPay < 10000 || basicPay > 500000 {
            issues.append(ValidationIssue(
                type: .outOfRange(.basicPay, value: basicPay, range: 10000...500000),
                severity: .warning,
                message: "Basic pay amount seems unusual",
                field: "basicPay"
            ))
        }
        
        // Check if basic pay is a reasonable percentage of total earnings
        let totalEarnings = payslip.payDetails.totalEarnings
        if totalEarnings > 0 {
            let basicPayPercentage = (basicPay / totalEarnings) * 100
            if basicPayPercentage < 30 || basicPayPercentage > 90 {
                issues.append(ValidationIssue(
                    type: .inconsistentData("Basic pay percentage", "\(basicPayPercentage)%"),
                    severity: .warning,
                    message: "Basic pay percentage of total earnings seems unusual",
                    field: "basicPay"
                ))
            }
        }
        
        return issues
    }
    
    private func validateTotalEarnings(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Calculate expected total earnings
        let basicPay = payslip.payDetails.basicPay
        let gradePay = payslip.payDetails.gradePay ?? 0
        let allowancesTotal = payslip.allowances.reduce(0) { $0 + $1.amount }
        
        let calculatedTotal = basicPay + gradePay + allowancesTotal
        let reportedTotal = payslip.payDetails.totalEarnings
        
        let difference = abs(calculatedTotal - reportedTotal)
        
        if difference > toleranceAmount {
            issues.append(ValidationIssue(
                type: .financialMismatch(expected: calculatedTotal, actual: reportedTotal, field: .totalEarnings),
                severity: .error,
                message: "Total earnings calculation mismatch",
                field: "totalEarnings"
            ))
        }
        
        return issues
    }
    
    private func validateTotalDeductions(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Calculate expected total deductions
        let deductionsTotal = payslip.deductions.reduce(0) { $0 + $1.amount }
        let reportedTotal = payslip.payDetails.totalDeductions
        
        let difference = abs(deductionsTotal - reportedTotal)
        
        if difference > toleranceAmount {
            issues.append(ValidationIssue(
                type: .financialMismatch(expected: deductionsTotal, actual: reportedTotal, field: .totalDeductions),
                severity: .error,
                message: "Total deductions calculation mismatch",
                field: "totalDeductions"
            ))
        }
        
        return issues
    }
    
    private func validateNetPayCalculation(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        let totalEarnings = payslip.payDetails.totalEarnings
        let totalDeductions = payslip.payDetails.totalDeductions
        let calculatedNet = totalEarnings - totalDeductions
        let reportedNet = payslip.payDetails.netPay
        
        let difference = abs(calculatedNet - reportedNet)
        
        if difference > toleranceAmount {
            issues.append(ValidationIssue(
                type: .financialMismatch(expected: calculatedNet, actual: reportedNet, field: .netPay),
                severity: .critical,
                message: "Net pay calculation mismatch: ₹\(totalEarnings) - ₹\(totalDeductions) ≠ ₹\(reportedNet)",
                field: "netPay"
            ))
        }
        
        return issues
    }
    
    private func validateAllowanceCalculations(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        for allowance in payslip.allowances {
            // Validate allowance amounts are reasonable
            if allowance.amount < 0 {
                issues.append(ValidationIssue(
                    type: .negativeAmount(.allowance, allowance.amount),
                    severity: .error,
                    message: "Allowance amount cannot be negative",
                    field: allowance.description
                ))
            }
            
            if allowance.amount > 50000 {
                issues.append(ValidationIssue(
                    type: .outOfRange(.allowance, value: allowance.amount, range: 0...50000),
                    severity: .warning,
                    message: "Unusually high allowance amount",
                    field: allowance.description
                ))
            }
        }
        
        return issues
    }
    
    private func validateDeductionCalculations(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        for deduction in payslip.deductions {
            // Validate deduction amounts are reasonable
            if deduction.amount < 0 {
                issues.append(ValidationIssue(
                    type: .negativeAmount(.deduction, deduction.amount),
                    severity: .error,
                    message: "Deduction amount cannot be negative",
                    field: deduction.description
                ))
            }
            
            // Check if statutory deduction amounts are reasonable
            if deduction.isStatutory {
                let totalEarnings = payslip.payDetails.totalEarnings
                let deductionPercentage = (deduction.amount / totalEarnings) * 100
                
                if deductionPercentage > 30 {
                    issues.append(ValidationIssue(
                        type: .outOfRange(.deduction, value: deductionPercentage, range: 0...30),
                        severity: .warning,
                        message: "Statutory deduction percentage seems high",
                        field: deduction.description
                    ))
                }
            }
        }
        
        return issues
    }
    
    private func validateEmployeeInfoConsistency(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check name consistency (all caps, reasonable length)
        let name = payslip.employeeInfo.name
        if name.count < 2 || name.count > 50 {
            issues.append(ValidationIssue(
                type: .invalidLength(.employeeName, expected: 2...50, actual: name.count),
                severity: .warning,
                message: "Employee name length is unusual",
                field: "employeeName"
            ))
        }
        
        // Check designation consistency
        if let designation = payslip.employeeInfo.designation {
            if !isValidMilitaryDesignation(designation) {
                issues.append(ValidationIssue(
                    type: .invalidFormat(.designation, expected: "Valid military rank", actual: designation),
                    severity: .warning,
                    message: "Designation does not match common military ranks",
                    field: "designation"
                ))
            }
        }
        
        return issues
    }
    
    private func validateBankDetailsConsistency(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if let accountNumber = payslip.bankDetails.accountNumber {
            if !isValidBankAccountNumber(accountNumber) {
                issues.append(ValidationIssue(
                    type: .invalidFormat(.accountNumber, expected: "9-18 digits", actual: accountNumber),
                    severity: .warning,
                    message: "Bank account number format appears invalid",
                    field: "accountNumber"
                ))
            }
        }
        
        if let ifscCode = payslip.bankDetails.ifscCode {
            if !isValidIFSCCode(ifscCode) {
                issues.append(ValidationIssue(
                    type: .invalidFormat(.ifscCode, expected: "ABCD0123456", actual: ifscCode),
                    severity: .warning,
                    message: "IFSC code format appears invalid",
                    field: "ifscCode"
                ))
            }
        }
        
        return issues
    }
    
    private func validatePayPeriodConsistency(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        let period = payslip.period
        
        // Validate pay month and year
        if let monthNum = Int(period.payMonth), monthNum < 1 || monthNum > 12 {
            issues.append(ValidationIssue(
                type: .outOfRange(.payMonth, value: Double(monthNum), range: 1...12),
                severity: .error,
                message: "Invalid pay month",
                field: "payMonth"
            ))
        }
        
        if let yearNum = Int(period.payYear) {
            let currentYear = Calendar.current.component(.year, from: Date())
            if yearNum < currentYear - 5 || yearNum > currentYear {
                issues.append(ValidationIssue(
                    type: .outOfRange(.payYear, value: Double(yearNum), range: Double(currentYear - 5)...Double(currentYear)),
                    severity: .warning,
                    message: "Pay year seems unusual",
                    field: "payYear"
                ))
            }
        }
        
        return issues
    }
    
    private func validateCrossReferences(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate gross pay consistency
        if payslip.netPay.grossPay != payslip.payDetails.totalEarnings {
            issues.append(ValidationIssue(
                type: .inconsistentData("Gross pay", "Net pay info vs pay details"),
                severity: .warning,
                message: "Gross pay values are inconsistent",
                field: "grossPay"
            ))
        }
        
        // Validate net amount consistency
        if payslip.netPay.netAmount != payslip.payDetails.netPay {
            issues.append(ValidationIssue(
                type: .inconsistentData("Net amount", "Net pay info vs pay details"),
                severity: .error,
                message: "Net amount values are inconsistent",
                field: "netAmount"
            ))
        }
        
        return issues
    }
    
    private func validateTemplateCompliance(_ payslip: MilitaryPayslip, template: PayslipTemplate) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check if mandatory fields from template are present
        for mandatoryField in template.mandatoryFields {
            if !hasRequiredField(payslip, fieldType: mandatoryField) {
                issues.append(ValidationIssue(
                    type: .missingRequiredField(mandatoryField),
                    severity: .critical,
                    message: "Mandatory field missing for template \(template.name)",
                    field: mandatoryField.rawValue
                ))
            }
        }
        
        return issues
    }
    
    private func validateRanges(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate confidence levels
        if payslip.confidence < confidenceThreshold {
            issues.append(ValidationIssue(
                type: .lowConfidence(.overallConfidence, payslip.confidence),
                severity: .warning,
                message: "Overall payslip confidence is low",
                field: "confidence"
            ))
        }
        
        return issues
    }
    
    private func validateDates(_ payslip: MilitaryPayslip) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate extraction date
        let extractionDate = payslip.extractionMetadata.extractionDate
        let now = Date()
        
        if extractionDate > now {
            issues.append(ValidationIssue(
                type: .futureDate(.extractionDate, extractionDate),
                severity: .error,
                message: "Extraction date cannot be in the future",
                field: "extractionDate"
            ))
        }
        
        return issues
    }
    
    // MARK: - Helper Methods
    
    private func calculateValidationScore(issues: [ValidationIssue], payslip: MilitaryPayslip) -> Float {
        let criticalCount = issues.filter { $0.severity == .critical }.count
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        
        var score: Float = 1.0
        
        // Deduct points based on severity
        score -= Float(criticalCount) * 0.3  // Critical issues heavily penalized
        score -= Float(errorCount) * 0.1     // Errors moderately penalized
        score -= Float(warningCount) * 0.05  // Warnings lightly penalized
        
        // Factor in payslip confidence
        score *= payslip.confidence
        
        return max(score, 0.0)
    }
    
    private func determineSeverity(issues: [ValidationIssue]) -> ValidationSeverity {
        if issues.contains(where: { $0.severity == .critical }) {
            return .critical
        } else if issues.contains(where: { $0.severity == .error }) {
            return .error
        } else if issues.contains(where: { $0.severity == .warning }) {
            return .warning
        } else {
            return .info
        }
    }
    
    private func isValidEmployeeId(_ id: String) -> Bool {
        return id.range(of: "^[0-9]{5,8}$", options: .regularExpression) != nil
    }
    
    private func isValidPAN(_ pan: String) -> Bool {
        return pan.range(of: "^[A-Z]{5}[0-9]{4}[A-Z]$", options: .regularExpression) != nil
    }
    
    private func isValidBankAccountNumber(_ account: String) -> Bool {
        return account.range(of: "^[0-9]{9,18}$", options: .regularExpression) != nil
    }
    
    private func isValidIFSCCode(_ ifsc: String) -> Bool {
        return ifsc.range(of: "^[A-Z]{4}0[A-Z0-9]{6}$", options: .regularExpression) != nil
    }
    
    private func isValidMilitaryDesignation(_ designation: String) -> Bool {
        let validDesignations = [
            "SEPOY", "NAIK", "HAVILDAR", "SERGEANT", "COMPANY HAVILDAR MAJOR",
            "SUBEDAR", "NAIB SUBEDAR", "JCO",
            "SECOND LIEUTENANT", "LIEUTENANT", "CAPTAIN", "MAJOR", "LIEUTENANT COLONEL", "COLONEL",
            "BRIGADIER", "MAJOR GENERAL", "LIEUTENANT GENERAL", "GENERAL"
        ]
        
        return validDesignations.contains { designation.uppercased().contains($0) }
    }
    
    private func hasRequiredField(_ payslip: MilitaryPayslip, fieldType: MilitaryPayslipFieldType) -> Bool {
        switch fieldType {
        case .employeeId:
            return !payslip.employeeInfo.employeeId.isEmpty
        case .employeeName:
            return !payslip.employeeInfo.name.isEmpty
        case .basicPay:
            return payslip.payDetails.basicPay > 0
        case .netPay:
            return payslip.payDetails.netPay > 0
        case .payPeriod:
            return !payslip.period.payMonth.isEmpty && !payslip.period.payYear.isEmpty
        default:
            return true // Non-critical fields
        }
    }
    
    private func attemptFormatCorrection(_ value: String, expectedFormat: String) -> String? {
        // Implementation would depend on the specific format expected
        // For now, return nil to indicate no correction possible
        return nil
    }
    
    private func clampToRange(_ value: Double, range: ClosedRange<Double>) -> Double {
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Supporting Data Structures

struct PayslipValidationReport {
    let isValid: Bool
    let score: Float
    let issues: [ValidationIssue]
    let suggestions: [CorrectionSuggestion]
    let severity: ValidationSeverity
    let validatedAt: Date
    let payslipConfidence: Float
    let templateUsed: String
}

struct ValidationIssue {
    let type: ValidationIssueType
    let severity: ValidationSeverity
    let message: String
    let field: String
}

struct CorrectionSuggestion {
    let issueType: ValidationIssueType
    let suggestedValue: String
    let currentValue: String
    let confidence: Float
    let reasoning: String
    let autoCorrectible: Bool
}

enum ValidationIssueType {
    case missingRequiredField(MilitaryPayslipFieldType)
    case invalidFormat(MilitaryPayslipFieldType, expected: String, actual: String)
    case outOfRange(MilitaryPayslipFieldType, value: Double, range: ClosedRange<Double>)
    case financialMismatch(expected: Double, actual: Double, field: MilitaryPayslipFieldType)
    case lowConfidence(MilitaryPayslipFieldType, Float)
    case negativeAmount(AmountType, Double)
    case inconsistentData(String, String)
    case invalidLength(MilitaryPayslipFieldType, expected: ClosedRange<Int>, actual: Int)
    case futureDate(DateFieldType, Date)
}

enum ValidationSeverity {
    case critical  // Blocks processing
    case error     // Significant issue
    case warning   // Minor issue
    case info      // Informational
}

enum AmountType {
    case allowance
    case deduction
    case payment
}

enum DateFieldType {
    case extractionDate
    case payPeriod
    case startDate
    case endDate
}

// Extension for MilitaryPayslipFieldType to support additional field types
extension MilitaryPayslipFieldType {
    static let overallConfidence = MilitaryPayslipFieldType.employeeId // Placeholder
    static let allowance = MilitaryPayslipFieldType.da // Placeholder
    static let deduction = MilitaryPayslipFieldType.providentFund // Placeholder
    static let extractionDate = MilitaryPayslipFieldType.payPeriod // Placeholder
} 