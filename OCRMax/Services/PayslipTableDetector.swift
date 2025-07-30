//
//  PayslipTableDetector.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import CoreGraphics

protocol PayslipTableDetectorProtocol {
    func detectPayslipStructure(in image: UIImage, textBlocks: [TextBlock]) async throws -> PayslipStructureAnalysis
    func validatePayslipFormat(analysis: PayslipStructureAnalysis) -> PayslipValidationResult
    func extractPayslipSections(from analysis: PayslipStructureAnalysis) -> PayslipSections
}

final class PayslipTableDetector: PayslipTableDetectorProtocol {
    
    private let payslipProcessor: PayslipImageProcessor
    private let tableParser: TableParserService
    private let enhancedAnalyzer: EnhancedLayoutAnalyzer
    
    init(payslipProcessor: PayslipImageProcessor = PayslipImageProcessor(),
         tableParser: TableParserService = TableParserService(),
         enhancedAnalyzer: EnhancedLayoutAnalyzer = EnhancedLayoutAnalyzer()) {
        self.payslipProcessor = payslipProcessor
        self.tableParser = tableParser
        self.enhancedAnalyzer = enhancedAnalyzer
    }
    
    enum DetectionError: LocalizedError {
        case invalidPayslipFormat
        case headerNotFound
        case dataTableNotFound
        case insufficientData
        
        var errorDescription: String? {
            switch self {
            case .invalidPayslipFormat:
                return "Document does not appear to be a valid payslip format"
            case .headerNotFound:
                return "Payslip header section not found"
            case .dataTableNotFound:
                return "Payslip data table not found"
            case .insufficientData:
                return "Insufficient data found in payslip for reliable processing"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func detectPayslipStructure(in image: UIImage, textBlocks: [TextBlock]) async throws -> PayslipStructureAnalysis {
        // Step 1: Detect basic table structure
        let tableStructure = try await payslipProcessor.detectTableStructure(in: image)
        
        // Step 2: Perform enhanced layout analysis
        let layoutAnalysis = enhancedAnalyzer.analyzeTableStructure(from: textBlocks, tableStructure: tableStructure)
        
        // Step 3: Parse the table with detailed cell analysis
        let parsedTable = try await tableParser.parseTable(textBlocks: textBlocks, tableStructure: tableStructure)
        
        // Step 4: Identify payslip-specific sections
        let payslipSections = identifyPayslipSections(from: layoutAnalysis, parsedTable: parsedTable)
        
        // Step 5: Extract key payslip fields
        let keyFields = extractKeyPayslipFields(from: textBlocks, sections: payslipSections)
        
        return PayslipStructureAnalysis(
            tableStructure: tableStructure,
            layoutAnalysis: layoutAnalysis,
            parsedTable: parsedTable,
            payslipSections: payslipSections,
            keyFields: keyFields,
            confidence: calculateOverallConfidence(layoutAnalysis: layoutAnalysis, parsedTable: parsedTable)
        )
    }
    
    func validatePayslipFormat(analysis: PayslipStructureAnalysis) -> PayslipValidationResult {
        var validationIssues: [PayslipValidationIssue] = []
        var score: Float = 1.0
        
        // Check for essential payslip elements
        if !hasRequiredHeaders(analysis: analysis) {
            validationIssues.append(.missingRequiredHeaders)
            score -= 0.3
        }
        
        if !hasValidEmployeeInfo(analysis: analysis) {
            validationIssues.append(.invalidEmployeeInfo)
            score -= 0.2
        }
        
        if !hasValidPayrollData(analysis: analysis) {
            validationIssues.append(.invalidPayrollData)
            score -= 0.2
        }
        
        if !hasValidAmounts(analysis: analysis) {
            validationIssues.append(.invalidAmounts)
            score -= 0.2
        }
        
        if !hasValidDateFormat(analysis: analysis) {
            validationIssues.append(.invalidDateFormat)
            score -= 0.1
        }
        
        // Check table structure quality
        if analysis.layoutAnalysis.confidence < 0.7 {
            validationIssues.append(.lowTableStructureConfidence)
            score -= 0.1
        }
        
        let validationLevel: PayslipValidationLevel
        if score >= 0.9 {
            validationLevel = .excellent
        } else if score >= 0.7 {
            validationLevel = .good
        } else if score >= 0.5 {
            validationLevel = .acceptable
        } else {
            validationLevel = .poor
        }
        
        return PayslipValidationResult(
            level: validationLevel,
            score: max(score, 0.0),
            issues: validationIssues,
            isValid: score >= 0.5
        )
    }
    
    func extractPayslipSections(from analysis: PayslipStructureAnalysis) -> PayslipSections {
        return analysis.payslipSections
    }
    
    // MARK: - Private Methods
    
    private func identifyPayslipSections(from layoutAnalysis: EnhancedLayoutAnalysis, parsedTable: ParsedTable) -> PayslipSections {
        var sections: [PayslipSectionType: PayslipSection] = [:]
        
        // Identify header section
        if let headerRegion = layoutAnalysis.tableRegions.first(where: { $0.type == .header }) {
            let headerSection = PayslipSection(
                type: .header,
                boundingBox: headerRegion.bounds,
                textBlocks: headerRegion.textBlocks,
                confidence: headerRegion.confidence
            )
            sections[.header] = headerSection
        }
        
        // Identify employee information section (typically in header or top rows)
        let employeeSection = identifyEmployeeInfoSection(from: layoutAnalysis)
        if let empSection = employeeSection {
            sections[.employeeInfo] = empSection
        }
        
        // Identify earnings section
        let earningsSection = identifyEarningsSection(from: parsedTable)
        if let earnSection = earningsSection {
            sections[.earnings] = earnSection
        }
        
        // Identify deductions section
        let deductionsSection = identifyDeductionsSection(from: parsedTable)
        if let deductSection = deductionsSection {
            sections[.deductions] = deductSection
        }
        
        // Identify net pay section
        let netPaySection = identifyNetPaySection(from: parsedTable)
        if let netSection = netPaySection {
            sections[.netPay] = netSection
        }
        
        // Identify bank details section
        let bankSection = identifyBankDetailsSection(from: layoutAnalysis)
        if let bankDetailsSection = bankSection {
            sections[.bankDetails] = bankDetailsSection
        }
        
        return PayslipSections(sections: sections)
    }
    
    private func identifyEmployeeInfoSection(from layoutAnalysis: EnhancedLayoutAnalysis) -> PayslipSection? {
        // Look for text blocks containing employee-related keywords
        let employeeKeywords = ["EMPLOYEE ID", "NAME", "DESIGNATION", "DEPARTMENT", "PAY LEVEL"]
        
        let employeeBlocks = layoutAnalysis.basicAnalysis.textGroups.flatMap { $0.blocks }.filter { block in
            employeeKeywords.contains { keyword in
                block.text.uppercased().contains(keyword)
            }
        }
        
        guard !employeeBlocks.isEmpty else { return nil }
        
        let boundingBox = calculateBoundingBox(for: employeeBlocks)
        let confidence = employeeBlocks.map { $0.confidence }.reduce(0, +) / Float(employeeBlocks.count)
        
        return PayslipSection(
            type: .employeeInfo,
            boundingBox: boundingBox,
            textBlocks: employeeBlocks,
            confidence: confidence
        )
    }
    
    private func identifyEarningsSection(from parsedTable: ParsedTable) -> PayslipSection? {
        let earningsKeywords = ["BASIC PAY", "GRADE PAY", "DA", "HRA", "ALLOWANCES", "CREDITS"]
        return identifySection(from: parsedTable, keywords: earningsKeywords, type: .earnings)
    }
    
    private func identifyDeductionsSection(from parsedTable: ParsedTable) -> PayslipSection? {
        let deductionsKeywords = ["DEDUCTIONS", "PF", "PLI", "INCOME TAX", "FAMO", "LOANS", "DEBITS"]
        return identifySection(from: parsedTable, keywords: deductionsKeywords, type: .deductions)
    }
    
    private func identifyNetPaySection(from parsedTable: ParsedTable) -> PayslipSection? {
        let netPayKeywords = ["NET PAY", "AMOUNT CREDITED", "TOTAL CREDITS", "CLOSING BALANCE"]
        return identifySection(from: parsedTable, keywords: netPayKeywords, type: .netPay)
    }
    
    private func identifyBankDetailsSection(from layoutAnalysis: EnhancedLayoutAnalysis) -> PayslipSection? {
        let bankKeywords = ["BANK", "ACCOUNT", "BRANCH", "IFSC"]
        
        let bankBlocks = layoutAnalysis.basicAnalysis.textGroups.flatMap { $0.blocks }.filter { block in
            bankKeywords.contains { keyword in
                block.text.uppercased().contains(keyword)
            }
        }
        
        guard !bankBlocks.isEmpty else { return nil }
        
        let boundingBox = calculateBoundingBox(for: bankBlocks)
        let confidence = bankBlocks.map { $0.confidence }.reduce(0, +) / Float(bankBlocks.count)
        
        return PayslipSection(
            type: .bankDetails,
            boundingBox: boundingBox,
            textBlocks: bankBlocks,
            confidence: confidence
        )
    }
    
    private func identifySection(from parsedTable: ParsedTable, keywords: [String], type: PayslipSectionType) -> PayslipSection? {
        var sectionBlocks: [TextBlock] = []
        
        for row in parsedTable.rows {
            for cellAnalysis in row.cells {
                let cellText = cellAnalysis.textBlocks.map { $0.text }.joined(separator: " ").uppercased()
                
                if keywords.contains(where: { cellText.contains($0) }) {
                    sectionBlocks.append(contentsOf: cellAnalysis.textBlocks)
                }
            }
        }
        
        guard !sectionBlocks.isEmpty else { return nil }
        
        let boundingBox = calculateBoundingBox(for: sectionBlocks)
        let confidence = sectionBlocks.map { $0.confidence }.reduce(0, +) / Float(sectionBlocks.count)
        
        return PayslipSection(
            type: type,
            boundingBox: boundingBox,
            textBlocks: sectionBlocks,
            confidence: confidence
        )
    }
    
    private func extractKeyPayslipFields(from textBlocks: [TextBlock], sections: PayslipSections) -> [PayslipField] {
        var fields: [PayslipField] = []
        
        // Extract employee ID
        if let employeeId = extractEmployeeId(from: textBlocks) {
            fields.append(employeeId)
        }
        
        // Extract employee name
        if let employeeName = extractEmployeeName(from: textBlocks) {
            fields.append(employeeName)
        }
        
        // Extract PAN number
        if let pan = extractPAN(from: textBlocks) {
            fields.append(pan)
        }
        
        // Extract net amount
        if let netAmount = extractNetAmount(from: textBlocks) {
            fields.append(netAmount)
        }
        
        // Extract pay period
        if let payPeriod = extractPayPeriod(from: textBlocks) {
            fields.append(payPeriod)
        }
        
        return fields
    }
    
    private func extractEmployeeId(from textBlocks: [TextBlock]) -> PayslipField? {
        let pattern = #"EMPLOYEE\s+ID[.\s:]*(\d+)"#
        return extractFieldWithPattern(from: textBlocks, pattern: pattern, fieldType: .employeeId, label: "Employee ID")
    }
    
    private func extractEmployeeName(from textBlocks: [TextBlock]) -> PayslipField? {
        let pattern = #"NAME[.\s:]*([A-Z\s]+)"#
        return extractFieldWithPattern(from: textBlocks, pattern: pattern, fieldType: .employeeName, label: "Employee Name")
    }
    
    private func extractPAN(from textBlocks: [TextBlock]) -> PayslipField? {
        let pattern = #"PAN[.\s:]*([A-Z]{5}\d{4}[A-Z])"#
        return extractFieldWithPattern(from: textBlocks, pattern: pattern, fieldType: .pan, label: "PAN")
    }
    
    private func extractNetAmount(from textBlocks: [TextBlock]) -> PayslipField? {
        let pattern = #"AMOUNT\s+CREDITED[.\s:]*(\d{1,}(?:,\d{3})*(?:\.\d{2})?)"#
        return extractFieldWithPattern(from: textBlocks, pattern: pattern, fieldType: .netAmount, label: "Net Amount")
    }
    
    private func extractPayPeriod(from textBlocks: [TextBlock]) -> PayslipField? {
        let pattern = #"(?:Month\s+Ending|FOR\s+THE\s+MTH)[.\s:]*(\d{2}\/\d{4})"#
        return extractFieldWithPattern(from: textBlocks, pattern: pattern, fieldType: .payPeriod, label: "Pay Period")
    }
    
    private func extractFieldWithPattern(from textBlocks: [TextBlock], pattern: String, fieldType: PayslipFieldType, label: String) -> PayslipField? {
        let combinedText = textBlocks.map { $0.text }.joined(separator: " ")
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: combinedText, options: [], range: NSRange(combinedText.startIndex..., in: combinedText)),
              let valueRange = Range(match.range(at: 1), in: combinedText) else {
            return nil
        }
        
        let value = String(combinedText[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return PayslipField(
            type: fieldType,
            label: label,
            value: value,
            confidence: 0.8
        )
    }
    
    private func calculateBoundingBox(for textBlocks: [TextBlock]) -> CGRect {
        guard !textBlocks.isEmpty else { return .zero }
        
        let minX = textBlocks.map { $0.boundingBox.minX }.min() ?? 0
        let minY = textBlocks.map { $0.boundingBox.minY }.min() ?? 0
        let maxX = textBlocks.map { $0.boundingBox.maxX }.max() ?? 0
        let maxY = textBlocks.map { $0.boundingBox.maxY }.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func calculateOverallConfidence(layoutAnalysis: EnhancedLayoutAnalysis, parsedTable: ParsedTable) -> Float {
        return (layoutAnalysis.confidence + parsedTable.confidence) / 2
    }
    
    // Validation helper methods
    private func hasRequiredHeaders(analysis: PayslipStructureAnalysis) -> Bool {
        let requiredHeaders = ["CREDITS", "DEBITS", "EMPLOYEE"]
        let headerTexts = analysis.parsedTable.headers.map { $0.text.uppercased() }
        
        return requiredHeaders.allSatisfy { required in
            headerTexts.contains { $0.contains(required) }
        }
    }
    
    private func hasValidEmployeeInfo(analysis: PayslipStructureAnalysis) -> Bool {
        let employeeFields = analysis.keyFields.filter { $0.type == .employeeId || $0.type == .employeeName }
        return employeeFields.count >= 1
    }
    
    private func hasValidPayrollData(analysis: PayslipStructureAnalysis) -> Bool {
        return analysis.parsedTable.rows.count >= 3 // At least some data rows
    }
    
    private func hasValidAmounts(analysis: PayslipStructureAnalysis) -> Bool {
        let amountFields = analysis.keyFields.filter { $0.type == .netAmount }
        return !amountFields.isEmpty
    }
    
    private func hasValidDateFormat(analysis: PayslipStructureAnalysis) -> Bool {
        let dateFields = analysis.keyFields.filter { $0.type == .payPeriod }
        return !dateFields.isEmpty
    }
}

// MARK: - Supporting Data Structures

struct PayslipStructureAnalysis {
    let tableStructure: PayslipTableStructure
    let layoutAnalysis: EnhancedLayoutAnalysis
    let parsedTable: ParsedTable
    let payslipSections: PayslipSections
    let keyFields: [PayslipField]
    let confidence: Float
}

struct PayslipSections {
    let sections: [PayslipSectionType: PayslipSection]
    
    func section(for type: PayslipSectionType) -> PayslipSection? {
        return sections[type]
    }
}

struct PayslipSection {
    let type: PayslipSectionType
    let boundingBox: CGRect
    let textBlocks: [TextBlock]
    let confidence: Float
}

struct PayslipField {
    let type: PayslipFieldType
    let label: String
    let value: String
    let confidence: Float
}

struct PayslipValidationResult {
    let level: PayslipValidationLevel
    let score: Float
    let issues: [PayslipValidationIssue]
    let isValid: Bool
}

enum PayslipSectionType: CaseIterable {
    case header
    case employeeInfo
    case earnings
    case deductions
    case netPay
    case bankDetails
}

enum PayslipFieldType: CaseIterable {
    case employeeId
    case employeeName
    case pan
    case netAmount
    case payPeriod
    case bankAccount
    case basicPay
    case totalDeductions
}

enum PayslipValidationLevel {
    case excellent  // 90-100%
    case good      // 70-89%
    case acceptable // 50-69%
    case poor      // <50%
}

enum PayslipValidationIssue {
    case missingRequiredHeaders
    case invalidEmployeeInfo
    case invalidPayrollData
    case invalidAmounts
    case invalidDateFormat
    case lowTableStructureConfidence
} 