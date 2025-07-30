//
//  PayslipValidatorTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 02/01/25.
//

import XCTest
@testable import OCRMax

class PayslipValidatorTests: XCTestCase {
    
    var payslipValidator: PayslipValidator!
    var samplePayslip: MilitaryPayslip!
    var sampleTemplate: PayslipTemplate!
    
    override func setUpWithError() throws {
        super.setUp()
        payslipValidator = PayslipValidator()
        samplePayslip = createSampleMilitaryPayslip()
        sampleTemplate = PayslipTemplate.getStandardMilitaryTemplate()
    }
    
    override func tearDownWithError() throws {
        payslipValidator = nil
        samplePayslip = nil
        sampleTemplate = nil
        super.tearDown()
    }
    
    // MARK: - Financial Validation Tests
    
    func testFinancialValidation_ValidCalculations() throws {
        // Given: A payslip with correct financial calculations
        let payslip = createPayslipWithFinancials(
            basicPay: 50000,
            allowances: [2000, 3000], // Total: 5000
            deductions: [1000, 500],  // Total: 1500
            totalEarnings: 55000,     // 50000 + 5000
            totalDeductions: 1500,
            netPay: 53500            // 55000 - 1500
        )
        
        // When
        let issues = payslipValidator.performFinancialValidation(payslip)
        
        // Then
        let financialIssues = issues.filter { issue in
            if case .financialMismatch = issue.type {
                return true
            }
            return false
        }
        XCTAssertTrue(financialIssues.isEmpty, "Should have no financial validation issues")
    }
    
    func testFinancialValidation_InvalidNetPayCalculation() throws {
        // Given: A payslip with incorrect net pay calculation
        let payslip = createPayslipWithFinancials(
            basicPay: 50000,
            allowances: [2000, 3000],
            deductions: [1000, 500],
            totalEarnings: 55000,
            totalDeductions: 1500,
            netPay: 50000  // Should be 53500, difference > tolerance
        )
        
        // When
        let issues = payslipValidator.performFinancialValidation(payslip)
        
        // Then
        let netPayIssues = issues.filter { issue in
            if case .financialMismatch(_, _, let field) = issue.type,
               field == .netPay {
                return true
            }
            return false
        }
        XCTAssertFalse(netPayIssues.isEmpty, "Should detect net pay calculation mismatch")
        XCTAssertEqual(netPayIssues.first?.severity, .critical, "Net pay mismatch should be critical")
    }
    
    func testFinancialValidation_TotalEarningsCalculation() throws {
        // Given: A payslip with incorrect total earnings
        let payslip = createPayslipWithFinancials(
            basicPay: 50000,
            allowances: [2000, 3000], // Total: 5000
            deductions: [1000, 500],
            totalEarnings: 60000,     // Should be 55000 (50000 + 5000)
            totalDeductions: 1500,
            netPay: 53500
        )
        
        // When
        let issues = payslipValidator.performFinancialValidation(payslip)
        
        // Then
        let earningsIssues = issues.filter { issue in
            if case .financialMismatch(_, _, let field) = issue.type,
               field == .totalEarnings {
                return true
            }
            return false
        }
        XCTAssertFalse(earningsIssues.isEmpty, "Should detect total earnings calculation mismatch")
    }
    
    func testFinancialValidation_NegativeAmount() throws {
        // Given: A payslip with negative allowance
        let payslip = createPayslipWithNegativeAmount()
        
        // When
        let issues = payslipValidator.performFinancialValidation(payslip)
        
        // Then
        let negativeAmountIssues = issues.filter { issue in
            if case .negativeAmount = issue.type {
                return true
            }
            return false
        }
        XCTAssertFalse(negativeAmountIssues.isEmpty, "Should detect negative amounts")
        XCTAssertEqual(negativeAmountIssues.first?.severity, .error, "Negative amounts should be errors")
    }
    
    // MARK: - Data Consistency Tests
    
    func testDataConsistency_ValidEmployeeInfo() throws {
        // Given: A payslip with valid employee information
        let payslip = createPayslipWithValidEmployeeInfo()
        
        // When
        let issues = payslipValidator.validateDataConsistency(payslip)
        
        // Then
        let employeeInfoIssues = issues.filter { issue in
            switch issue.type {
            case .invalidFormat(.employeeName, _, _),
                 .invalidFormat(.employeeId, _, _),
                 .invalidLength(.employeeName, _, _):
                return true
            default:
                return false
            }
        }
        XCTAssertTrue(employeeInfoIssues.isEmpty, "Should have no employee info consistency issues")
    }
    
    func testDataConsistency_InvalidPANFormat() throws {
        // Given: A payslip with invalid PAN format
        let payslip = createPayslipWithInvalidPAN()
        
        // When
        let issues = payslipValidator.validateDataConsistency(payslip)
        
        // Then
        let panIssues = issues.filter { issue in
            if case .invalidFormat(.panNumber, _, _) = issue.type {
                return true
            }
            return false
        }
        XCTAssertFalse(panIssues.isEmpty, "Should detect invalid PAN format")
    }
    
    func testDataConsistency_InvalidBankAccountNumber() throws {
        // Given: A payslip with invalid bank account format
        let payslip = createPayslipWithInvalidBankAccount()
        
        // When
        let issues = payslipValidator.validateDataConsistency(payslip)
        
        // Then
        let bankAccountIssues = issues.filter { issue in
            if case .invalidFormat(.accountNumber, _, _) = issue.type {
                return true
            }
            return false
        }
        XCTAssertFalse(bankAccountIssues.isEmpty, "Should detect invalid bank account format")
    }
    
    // MARK: - Template Compliance Tests
    
    func testValidateMilitaryPayslip_ValidPayslip() async throws {
        // Given: A valid military payslip
        let validPayslip = createValidMilitaryPayslip()
        
        // When
        let report = try await payslipValidator.validateMilitaryPayslip(validPayslip, template: sampleTemplate)
        
        // Then
        XCTAssertTrue(report.score >= 0.8, "Valid payslip should have high validation score")
        XCTAssertTrue(report.isValid, "Valid payslip should pass validation")
        let criticalIssues = report.issues.filter { $0.severity == .critical }
        XCTAssertTrue(criticalIssues.isEmpty, "Valid payslip should have no critical issues")
    }
    
    func testValidateMilitaryPayslip_MissingMandatoryFields() async throws {
        // Given: A payslip missing mandatory fields
        let invalidPayslip = createPayslipMissingMandatoryFields()
        
        // When
        let report = try await payslipValidator.validateMilitaryPayslip(invalidPayslip, template: sampleTemplate)
        
        // Then
        XCTAssertFalse(report.isValid, "Payslip with missing mandatory fields should fail validation")
        let missingFieldIssues = report.issues.filter { issue in
            if case .missingRequiredField = issue.type {
                return true
            }
            return false
        }
        XCTAssertFalse(missingFieldIssues.isEmpty, "Should detect missing mandatory fields")
    }
    
    func testValidateMilitaryPayslip_LowConfidence() async throws {
        // Given: A payslip with low confidence
        let lowConfidencePayslip = createLowConfidencePayslip()
        
        // When
        let report = try await payslipValidator.validateMilitaryPayslip(lowConfidencePayslip, template: sampleTemplate)
        
        // Then
        XCTAssertTrue(report.score < 0.7, "Low confidence payslip should have low validation score")
        let confidenceIssues = report.issues.filter { issue in
            if case .lowConfidence = issue.type {
                return true
            }
            return false
        }
        XCTAssertFalse(confidenceIssues.isEmpty, "Should detect low confidence issues")
    }
    
    // MARK: - Correction Suggestions Tests
    
    func testSuggestCorrections_FinancialMismatch() throws {
        // Given: Issues with financial mismatch
        let issues = [
            ValidationIssue(
                type: .financialMismatch(expected: 53500, actual: 50000, field: .netPay),
                severity: .critical,
                message: "Net pay calculation mismatch",
                field: "netPay"
            )
        ]
        
        // When
        let suggestions = payslipValidator.suggestCorrections(for: issues, payslip: samplePayslip)
        
        // Then
        XCTAssertFalse(suggestions.isEmpty, "Should provide correction suggestions")
        let financialSuggestion = suggestions.first { $0.autoCorrectible }
        XCTAssertNotNil(financialSuggestion, "Financial mismatch should be auto-correctable")
        XCTAssertEqual(financialSuggestion?.suggestedValue, "53500.0", "Should suggest correct financial value")
    }
    
    func testSuggestCorrections_InvalidFormat() throws {
        // Given: Issues with invalid format
        let issues = [
            ValidationIssue(
                type: .invalidFormat(.employeeId, expected: "5-8 digits", actual: "ABC123"),
                severity: .warning,
                message: "Employee ID format invalid",
                field: "employeeId"
            )
        ]
        
        // When
        let suggestions = payslipValidator.suggestCorrections(for: issues, payslip: samplePayslip)
        
        // Then
        XCTAssertFalse(suggestions.isEmpty, "Should provide format correction suggestions")
    }
    
    func testSuggestCorrections_LowConfidence() throws {
        // Given: Issues with low confidence
        let issues = [
            ValidationIssue(
                type: .lowConfidence(.employeeName, 0.4),
                severity: .warning,
                message: "Low confidence field",
                field: "employeeName"
            )
        ]
        
        // When
        let suggestions = payslipValidator.suggestCorrections(for: issues, payslip: samplePayslip)
        
        // Then
        XCTAssertFalse(suggestions.isEmpty, "Should provide low confidence suggestions")
        let lowConfidenceSuggestion = suggestions.first
        XCTAssertNotNil(lowConfidenceSuggestion, "Should suggest manual review")
        XCTAssertFalse(lowConfidenceSuggestion!.autoCorrectible, "Low confidence should not be auto-correctable")
    }
    
    // MARK: - Range Validation Tests
    
    func testRangeValidation_BasicPayOutOfRange() throws {
        // Given: A payslip with basic pay out of reasonable range
        let payslip = createPayslipWithBasicPay(1000) // Too low
        
        // When
        let issues = payslipValidator.performFinancialValidation(payslip)
        
        // Then
        let rangeIssues = issues.filter { issue in
            if case .outOfRange(.basicPay, _, _) = issue.type {
                return true
            }
            return false
        }
        XCTAssertFalse(rangeIssues.isEmpty, "Should detect basic pay out of range")
    }
    
    func testRangeValidation_ValidBasicPay() throws {
        // Given: A payslip with valid basic pay
        let payslip = createPayslipWithBasicPay(50000) // Valid range
        
        // When
        let issues = payslipValidator.performFinancialValidation(payslip)
        
        // Then
        let rangeIssues = issues.filter { issue in
            if case .outOfRange(.basicPay, _, _) = issue.type {
                return true
            }
            return false
        }
        XCTAssertTrue(rangeIssues.isEmpty, "Should not flag valid basic pay")
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() async throws {
        // Given: A complex payslip
        let complexPayslip = createComplexMilitaryPayslip()
        
        // When
        let startTime = Date()
        let _ = try await payslipValidator.validateMilitaryPayslip(complexPayslip, template: sampleTemplate)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(executionTime, 2.0, "Validation should complete within 2 seconds")
    }
    
    // MARK: - Helper Methods
    
    private func createSampleMilitaryPayslip() -> MilitaryPayslip {
        return MilitaryPayslip(
            employeeInfo: EmployeeInfo(
                employeeId: "123456",
                name: "JOHN DOE",
                designation: "SEPOY",
                department: "INFANTRY",
                payLevel: "3",
                panNumber: "ABCDE1234F",
                serviceNumber: "1234567890"
            ),
            payDetails: PayDetails(
                basicPay: 50000,
                gradePay: 5000,
                totalEarnings: 60000,
                totalDeductions: 5000,
                netPay: 55000
            ),
            allowances: [
                Allowance(type: .dearnesAllowance, description: "DA", amount: 3000, isFixed: false),
                Allowance(type: .houseRentAllowance, description: "HRA", amount: 2000, isFixed: false)
            ],
            deductions: [
                Deduction(type: .providentFund, description: "PF", amount: 3000, isStatutory: true),
                Deduction(type: .incomeTax, description: "Income Tax", amount: 2000, isStatutory: true)
            ],
            netPay: NetPayInfo(
                grossPay: 60000,
                totalDeductions: 5000,
                netAmount: 55000,
                amountInWords: "Fifty Five Thousand Only"
            ),
            bankDetails: BankInfo(
                bankName: "STATE BANK OF INDIA",
                accountNumber: "123456789012345",
                branchCode: "001234",
                ifscCode: "SBIN0001234"
            ),
            period: PayPeriod(
                startDate: nil,
                endDate: nil,
                payMonth: "12",
                payYear: "2024"
            ),
            confidence: 0.9,
            extractionMetadata: ExtractionMetadata(
                extractionDate: Date(),
                templateUsed: "military_standard_v1",
                confidence: 0.9,
                processingTime: 1.0,
                validationScore: 0.95
            )
        )
    }
    
    private func createPayslipWithFinancials(
        basicPay: Double,
        allowances: [Double],
        deductions: [Double],
        totalEarnings: Double,
        totalDeductions: Double,
        netPay: Double
    ) -> MilitaryPayslip {
        
        let allowanceObjects = allowances.enumerated().map { index, amount in
            Allowance(
                type: index == 0 ? .dearnesAllowance : .houseRentAllowance,
                description: "Allowance \(index + 1)",
                amount: amount,
                isFixed: false
            )
        }
        
        let deductionObjects = deductions.enumerated().map { index, amount in
            Deduction(
                type: index == 0 ? .providentFund : .incomeTax,
                description: "Deduction \(index + 1)",
                amount: amount,
                isStatutory: true
            )
        }
        
        var payslip = samplePayslip!
        payslip = MilitaryPayslip(
            employeeInfo: payslip.employeeInfo,
            payDetails: PayDetails(
                basicPay: basicPay,
                gradePay: 0,
                totalEarnings: totalEarnings,
                totalDeductions: totalDeductions,
                netPay: netPay
            ),
            allowances: allowanceObjects,
            deductions: deductionObjects,
            netPay: payslip.netPay,
            bankDetails: payslip.bankDetails,
            period: payslip.period,
            confidence: payslip.confidence,
            extractionMetadata: payslip.extractionMetadata
        )
        
        return payslip
    }
    
    private func createPayslipWithNegativeAmount() -> MilitaryPayslip {
        return createPayslipWithFinancials(
            basicPay: 50000,
            allowances: [-1000, 2000], // Negative allowance
            deductions: [1000, 500],
            totalEarnings: 51000,
            totalDeductions: 1500,
            netPay: 49500
        )
    }
    
    private func createPayslipWithValidEmployeeInfo() -> MilitaryPayslip {
        var payslip = samplePayslip!
        payslip = MilitaryPayslip(
            employeeInfo: EmployeeInfo(
                employeeId: "123456",
                name: "JOHN DOE",
                designation: "SEPOY",
                department: "INFANTRY",
                payLevel: "3",
                panNumber: "ABCDE1234F",
                serviceNumber: "1234567890"
            ),
            payDetails: payslip.payDetails,
            allowances: payslip.allowances,
            deductions: payslip.deductions,
            netPay: payslip.netPay,
            bankDetails: payslip.bankDetails,
            period: payslip.period,
            confidence: payslip.confidence,
            extractionMetadata: payslip.extractionMetadata
        )
        return payslip
    }
    
    private func createPayslipWithInvalidPAN() -> MilitaryPayslip {
        var payslip = samplePayslip!
        payslip = MilitaryPayslip(
            employeeInfo: EmployeeInfo(
                employeeId: payslip.employeeInfo.employeeId,
                name: payslip.employeeInfo.name,
                designation: payslip.employeeInfo.designation,
                department: payslip.employeeInfo.department,
                payLevel: payslip.employeeInfo.payLevel,
                panNumber: "INVALID123", // Invalid PAN format
                serviceNumber: payslip.employeeInfo.serviceNumber
            ),
            payDetails: payslip.payDetails,
            allowances: payslip.allowances,
            deductions: payslip.deductions,
            netPay: payslip.netPay,
            bankDetails: payslip.bankDetails,
            period: payslip.period,
            confidence: payslip.confidence,
            extractionMetadata: payslip.extractionMetadata
        )
        return payslip
    }
    
    private func createPayslipWithInvalidBankAccount() -> MilitaryPayslip {
        var payslip = samplePayslip!
        payslip = MilitaryPayslip(
            employeeInfo: payslip.employeeInfo,
            payDetails: payslip.payDetails,
            allowances: payslip.allowances,
            deductions: payslip.deductions,
            netPay: payslip.netPay,
            bankDetails: BankInfo(
                bankName: payslip.bankDetails.bankName,
                accountNumber: "123", // Too short
                branchCode: payslip.bankDetails.branchCode,
                ifscCode: payslip.bankDetails.ifscCode
            ),
            period: payslip.period,
            confidence: payslip.confidence,
            extractionMetadata: payslip.extractionMetadata
        )
        return payslip
    }
    
    private func createValidMilitaryPayslip() -> MilitaryPayslip {
        return samplePayslip
    }
    
    private func createPayslipMissingMandatoryFields() -> MilitaryPayslip {
        var payslip = samplePayslip!
        payslip = MilitaryPayslip(
            employeeInfo: EmployeeInfo(
                employeeId: "", // Missing mandatory field
                name: payslip.employeeInfo.name,
                designation: payslip.employeeInfo.designation,
                department: payslip.employeeInfo.department,
                payLevel: payslip.employeeInfo.payLevel,
                panNumber: payslip.employeeInfo.panNumber,
                serviceNumber: payslip.employeeInfo.serviceNumber
            ),
            payDetails: payslip.payDetails,
            allowances: payslip.allowances,
            deductions: payslip.deductions,
            netPay: payslip.netPay,
            bankDetails: payslip.bankDetails,
            period: payslip.period,
            confidence: payslip.confidence,
            extractionMetadata: payslip.extractionMetadata
        )
        return payslip
    }
    
    private func createLowConfidencePayslip() -> MilitaryPayslip {
        var payslip = samplePayslip!
        payslip = MilitaryPayslip(
            employeeInfo: payslip.employeeInfo,
            payDetails: payslip.payDetails,
            allowances: payslip.allowances,
            deductions: payslip.deductions,
            netPay: payslip.netPay,
            bankDetails: payslip.bankDetails,
            period: payslip.period,
            confidence: 0.4, // Low confidence
            extractionMetadata: payslip.extractionMetadata
        )
        return payslip
    }
    
    private func createPayslipWithBasicPay(_ basicPay: Double) -> MilitaryPayslip {
        return createPayslipWithFinancials(
            basicPay: basicPay,
            allowances: [2000, 3000],
            deductions: [1000, 500],
            totalEarnings: basicPay + 5000,
            totalDeductions: 1500,
            netPay: basicPay + 3500
        )
    }
    
    private func createComplexMilitaryPayslip() -> MilitaryPayslip {
        return createPayslipWithFinancials(
            basicPay: 75000,
            allowances: [5000, 3000, 2000, 1500, 1000], // 5 allowances
            deductions: [7500, 2250, 1500, 500, 250], // 5 deductions
            totalEarnings: 87500,
            totalDeductions: 12000,
            netPay: 75500
        )
    }
} 