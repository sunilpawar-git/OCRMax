//
//  ConfidenceBoosterTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 02/01/25.
//

import XCTest
@testable import OCRMax

class ConfidenceBoosterTests: XCTestCase {
    
    var confidenceBooster: ConfidenceBooster!
    var sampleTextBlocks: [TextBlock]!
    var samplePayslipContext: PayslipContext!
    var sampleImage: UIImage!
    
    override func setUpWithError() throws {
        super.setUp()
        confidenceBooster = ConfidenceBooster()
        sampleTextBlocks = createSampleTextBlocks()
        samplePayslipContext = createSamplePayslipContext()
        sampleImage = createSampleImage()
    }
    
    override func tearDownWithError() throws {
        confidenceBooster = nil
        sampleTextBlocks = nil
        samplePayslipContext = nil
        sampleImage = nil
        super.tearDown()
    }
    
    // MARK: - Text Enhancement Tests
    
    func testEnhanceTextBlocks_LowConfidenceImprovement() async throws {
        // Given: Text blocks with low confidence
        let lowConfidenceBlocks = [
            TextBlock(text: "JOHN D0E", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.6, pageIndex: 0),
            TextBlock(text: "I23456", boundingBox: CGRect(x: 0, y: 25, width: 100, height: 20), confidence: 0.5, pageIndex: 0)
        ]
        
        // When
        let enhancedBlocks = try await confidenceBooster.enhanceTextBlocks(lowConfidenceBlocks, using: samplePayslipContext)
        
        // Then
        XCTAssertEqual(enhancedBlocks.count, lowConfidenceBlocks.count, "Should return same number of blocks")
        
        // Check that low confidence blocks were processed
        let processedBlocks = enhancedBlocks.filter { $0.confidence > 0.6 }
        XCTAssertFalse(processedBlocks.isEmpty, "Should have enhanced some low confidence blocks")
    }
    
    func testEnhanceTextBlocks_HighConfidenceUnchanged() async throws {
        // Given: Text blocks with high confidence
        let highConfidenceBlocks = [
            TextBlock(text: "JOHN DOE", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, pageIndex: 0),
            TextBlock(text: "123456", boundingBox: CGRect(x: 0, y: 25, width: 100, height: 20), confidence: 0.95, pageIndex: 0)
        ]
        
        // When
        let enhancedBlocks = try await confidenceBooster.enhanceTextBlocks(highConfidenceBlocks, using: samplePayslipContext)
        
        // Then
        XCTAssertEqual(enhancedBlocks.count, highConfidenceBlocks.count, "Should return same number of blocks")
        
        // High confidence blocks should remain largely unchanged
        for (original, enhanced) in zip(highConfidenceBlocks, enhancedBlocks) {
            if original.confidence >= 0.7 {
                XCTAssertEqual(enhanced.text, original.text, "High confidence text should not change")
            }
        }
    }
    
    // MARK: - Field Reprocessing Tests
    
    func testReprocessLowConfidenceFields_Improvement() async throws {
        // Given: Fields with low confidence
        let lowConfidenceFields = [
            MilitaryPayslipField(
                type: .employeeId,
                label: "Employee ID",
                value: "I23456O", // OCR errors
                confidence: 0.4,
                source: .patternMatching,
                isRequired: true
            ),
            MilitaryPayslipField(
                type: .panNumber,
                label: "PAN",
                value: "ABCDE1234F", // Actually correct
                confidence: 0.3,
                source: .patternMatching,
                isRequired: false
            )
        ]
        
        // When
        let improvedFields = try await confidenceBooster.reprocessLowConfidenceFields(lowConfidenceFields, originalImage: sampleImage)
        
        // Then
        XCTAssertEqual(improvedFields.count, lowConfidenceFields.count, "Should return same number of fields")
        
        // Check improvements
        let employeeIdField = improvedFields.first { $0.type == .employeeId }
        XCTAssertNotNil(employeeIdField, "Should have employee ID field")
        XCTAssertTrue(employeeIdField!.confidence > 0.4, "Employee ID confidence should improve")
        
        let panField = improvedFields.first { $0.type == .panNumber }
        XCTAssertNotNil(panField, "Should have PAN field")
        XCTAssertTrue(panField!.confidence > 0.3, "PAN confidence should improve due to valid format")
    }
    
    func testReprocessLowConfidenceFields_HighConfidenceUnchanged() async throws {
        // Given: Fields with high confidence
        let highConfidenceFields = [
            MilitaryPayslipField(
                type: .employeeName,
                label: "Name",
                value: "JOHN DOE",
                confidence: 0.9,
                source: .patternMatching,
                isRequired: true
            )
        ]
        
        // When
        let improvedFields = try await confidenceBooster.reprocessLowConfidenceFields(highConfidenceFields, originalImage: sampleImage)
        
        // Then
        XCTAssertEqual(improvedFields.count, highConfidenceFields.count, "Should return same number of fields")
        XCTAssertEqual(improvedFields.first?.value, "JOHN DOE", "High confidence field should remain unchanged")
        XCTAssertEqual(improvedFields.first?.confidence, 0.9, "High confidence should remain unchanged")
    }
    
    // MARK: - Contextual Correction Tests
    
    func testApplyContextualCorrection_EmployeeId() throws {
        // Given: Employee ID with OCR errors
        let context = FieldContext(
            fieldType: .employeeId,
            surroundingText: ["EMPLOYEE", "ID"],
            expectedPattern: "^[0-9]{5,8}$",
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("I23456O", context: context)
        
        // Then
        XCTAssertTrue(result.wasModified, "Should modify text with OCR errors")
        XCTAssertEqual(result.correctedText, "1234560", "Should correct I→1 and O→0")
        XCTAssertGreaterThan(result.confidenceBoost, 0, "Should boost confidence")
    }
    
    func testApplyContextualCorrection_EmployeeName() throws {
        // Given: Employee name with formatting issues
        let context = FieldContext(
            fieldType: .employeeName,
            surroundingText: ["NAME"],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("  j0hn  d0e  ", context: context)
        
        // Then
        XCTAssertTrue(result.wasModified, "Should modify name formatting")
        XCTAssertEqual(result.correctedText, "JOHN DOE", "Should clean and format name")
        XCTAssertGreaterThan(result.confidenceBoost, 0, "Should boost confidence")
    }
    
    func testApplyContextualCorrection_PANNumber() throws {
        // Given: PAN number with OCR errors
        let context = FieldContext(
            fieldType: .panNumber,
            surroundingText: ["PAN"],
            expectedPattern: "^[A-Z]{5}[0-9]{4}[A-Z]$",
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("ABCDE12345", context: context)
        
        // Then
        XCTAssertFalse(result.wasModified, "Should not modify if pattern doesn't match after correction")
        XCTAssertEqual(result.correctedText, "ABCDE12345", "Should return cleaned text")
    }
    
    func testApplyContextualCorrection_FinancialAmount() throws {
        // Given: Financial amount with currency symbols and OCR errors
        let context = FieldContext(
            fieldType: .basicPay,
            surroundingText: ["BASIC", "PAY"],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("Rs. 5O,OOO", context: context)
        
        // Then
        XCTAssertTrue(result.wasModified, "Should modify financial amount")
        XCTAssertEqual(result.correctedText, "50,000", "Should correct O→0 and remove currency symbols")
        XCTAssertGreaterThan(result.confidenceBoost, 0, "Should boost confidence for valid number")
    }
    
    func testApplyContextualCorrection_DateField() throws {
        // Given: Date field with formatting issues
        let context = FieldContext(
            fieldType: .payPeriod,
            surroundingText: ["PAY", "PERIOD"],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("122024", context: context)
        
        // Then
        XCTAssertTrue(result.wasModified, "Should modify date format")
        XCTAssertEqual(result.correctedText, "12/2024", "Should format as MM/YYYY")
        XCTAssertGreaterThan(result.confidenceBoost, 0, "Should boost confidence for formatted date")
    }
    
    // MARK: - Dictionary Validation Tests
    
    func testValidateWithDictionary_ValidMilitaryRank() throws {
        // Given: Valid military rank
        let rank = "SEPOY"
        
        // When
        let result = confidenceBooster.validateWithDictionary(rank, fieldType: .designation)
        
        // Then
        XCTAssertTrue(result.isValid, "SEPOY should be valid military rank")
        XCTAssertEqual(result.confidence, 1.0, "Valid rank should have full confidence")
        XCTAssertEqual(result.matchType, .exact, "Should be exact match")
    }
    
    func testValidateWithDictionary_InvalidMilitaryRank() throws {
        // Given: Invalid military rank
        let rank = "INVALID_RANK"
        
        // When
        let result = confidenceBooster.validateWithDictionary(rank, fieldType: .designation)
        
        // Then
        XCTAssertFalse(result.isValid, "Invalid rank should not be valid")
        XCTAssertEqual(result.confidence, 0.0, "Invalid rank should have zero confidence")
        XCTAssertEqual(result.matchType, .none, "Should have no match")
    }
    
    func testValidateWithDictionary_PartialMilitaryRank() throws {
        // Given: Partial military rank
        let rank = "HAVILDAR"
        
        // When
        let result = confidenceBooster.validateWithDictionary(rank, fieldType: .designation)
        
        // Then
        XCTAssertTrue(result.isValid, "HAVILDAR should be valid military rank")
        XCTAssertEqual(result.confidence, 1.0, "Valid rank should have full confidence")
    }
    
    func testValidateWithDictionary_ValidBankName() throws {
        // Given: Valid bank name
        let bankName = "STATE BANK OF INDIA"
        
        // When
        let result = confidenceBooster.validateWithDictionary(bankName, fieldType: .bankName)
        
        // Then
        XCTAssertTrue(result.isValid, "SBI should be valid bank name")
        XCTAssertEqual(result.confidence, 0.9, "Valid bank should have high confidence")
        XCTAssertEqual(result.matchType, .exact, "Should be exact match")
    }
    
    func testValidateWithDictionary_InvalidBankName() throws {
        // Given: Invalid bank name
        let bankName = "UNKNOWN BANK"
        
        // When
        let result = confidenceBooster.validateWithDictionary(bankName, fieldType: .bankName)
        
        // Then
        XCTAssertFalse(result.isValid, "Unknown bank should not be valid")
        XCTAssertEqual(result.confidence, 0.5, "Unknown bank should have low confidence")
        XCTAssertEqual(result.matchType, .none, "Should have no match")
    }
    
    func testValidateWithDictionary_NonDictionaryField() throws {
        // Given: Field type not in dictionary
        let value = "ANY_VALUE"
        
        // When
        let result = confidenceBooster.validateWithDictionary(value, fieldType: .employeeId)
        
        // Then
        XCTAssertTrue(result.isValid, "Non-dictionary fields should pass validation")
        XCTAssertEqual(result.confidence, 1.0, "Should have full confidence")
        XCTAssertEqual(result.matchType, .exact, "Should be exact match")
    }
    
    // MARK: - Field-Specific Correction Tests
    
    func testCorrectEmployeeId_ValidFormat() throws {
        // Given: Employee ID with common OCR errors
        let context = FieldContext(
            fieldType: .employeeId,
            surroundingText: [],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("l23456O", context: context)
        
        // Then
        XCTAssertEqual(result.correctedText, "1234560", "Should correct l→1 and O→0")
        XCTAssertTrue(result.wasModified, "Should be modified")
    }
    
    func testCorrectPANNumber_ValidFormat() throws {
        // Given: PAN number with correct format
        let context = FieldContext(
            fieldType: .panNumber,
            surroundingText: [],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("ABCDE1234F", context: context)
        
        // Then
        XCTAssertEqual(result.correctedText, "ABCDE1234F", "Valid PAN should remain unchanged")
        XCTAssertGreaterThan(result.confidenceBoost, 0, "Valid PAN should boost confidence")
    }
    
    func testCorrectBankAccountNumber_ValidLength() throws {
        // Given: Bank account number with non-numeric characters
        let context = FieldContext(
            fieldType: .accountNumber,
            surroundingText: [],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("123-456-789-012", context: context)
        
        // Then
        XCTAssertEqual(result.correctedText, "123456789012", "Should remove non-numeric characters")
        XCTAssertTrue(result.wasModified, "Should be modified")
        XCTAssertGreaterThan(result.confidenceBoost, 0, "Valid length should boost confidence")
    }
    
    // MARK: - Performance Tests
    
    func testEnhanceTextBlocksPerformance() async throws {
        // Given: Large number of low confidence text blocks
        let manyTextBlocks = (0..<100).map { index in
            TextBlock(
                text: "Text \(index)",
                boundingBox: CGRect(x: 0, y: CGFloat(index * 20), width: 100, height: 20),
                confidence: 0.5,
                pageIndex: 0
            )
        }
        
        // When
        let startTime = Date()
        let _ = try await confidenceBooster.enhanceTextBlocks(manyTextBlocks, using: samplePayslipContext)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(executionTime, 5.0, "Enhancement should complete within 5 seconds for 100 blocks")
    }
    
    func testReprocessFieldsPerformance() async throws {
        // Given: Many low confidence fields
        let manyFields = (0..<50).map { index in
            MilitaryPayslipField(
                type: .employeeName,
                label: "Field \(index)",
                value: "Value \(index)",
                confidence: 0.4,
                source: .patternMatching,
                isRequired: false
            )
        }
        
        // When
        let startTime = Date()
        let _ = try await confidenceBooster.reprocessLowConfidenceFields(manyFields, originalImage: sampleImage)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(executionTime, 3.0, "Reprocessing should complete within 3 seconds for 50 fields")
    }
    
    // MARK: - Edge Cases Tests
    
    func testApplyContextualCorrection_EmptyText() throws {
        // Given: Empty text
        let context = FieldContext(
            fieldType: .employeeName,
            surroundingText: [],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("", context: context)
        
        // Then
        XCTAssertEqual(result.correctedText, "", "Empty text should remain empty")
        XCTAssertFalse(result.wasModified, "Empty text should not be modified")
        XCTAssertEqual(result.confidenceBoost, 0, "Empty text should not boost confidence")
    }
    
    func testApplyContextualCorrection_WhitespaceOnly() throws {
        // Given: Whitespace only text
        let context = FieldContext(
            fieldType: .employeeName,
            surroundingText: [],
            expectedPattern: nil,
            position: CGRect.zero
        )
        
        // When
        let result = confidenceBooster.applyContextualCorrection("   \n\t  ", context: context)
        
        // Then
        XCTAssertEqual(result.correctedText, "", "Whitespace should be trimmed to empty")
        XCTAssertTrue(result.wasModified, "Whitespace should be modified")
    }
    
    func testEnhanceTextBlocks_EmptyInput() async throws {
        // Given: Empty text blocks array
        let emptyBlocks: [TextBlock] = []
        
        // When
        let result = try await confidenceBooster.enhanceTextBlocks(emptyBlocks, using: samplePayslipContext)
        
        // Then
        XCTAssertTrue(result.isEmpty, "Empty input should return empty output")
    }
    
    // MARK: - Helper Methods
    
    private func createSampleTextBlocks() -> [TextBlock] {
        return [
            TextBlock(
                text: "EMPLOYEE ID",
                boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
                confidence: 0.9,
                pageIndex: 0
            ),
            TextBlock(
                text: "123456",
                boundingBox: CGRect(x: 0, y: 25, width: 100, height: 20),
                confidence: 0.8,
                pageIndex: 0
            ),
            TextBlock(
                text: "J0HN D0E", // OCR errors
                boundingBox: CGRect(x: 0, y: 50, width: 100, height: 20),
                confidence: 0.6,
                pageIndex: 0
            )
        ]
    }
    
    private func createSamplePayslipContext() -> PayslipContext {
        return PayslipContext(
            surroundingText: ["EMPLOYEE", "ID", "NAME", "BASIC", "PAY"],
            documentType: "military_payslip",
            expectedFields: [.employeeId, .employeeName, .basicPay, .netPay]
        )
    }
    
    private func createSampleImage() -> UIImage {
        // Create a simple test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
} 