//
//  MilitaryPayslipModels.swift
//  OCRMax
//
//  Created by Sunil Pawar on 02/01/25.
//

import Foundation
import CoreGraphics

// MARK: - Military Payslip Structure

struct MilitaryPayslip: Codable {
    let employeeInfo: EmployeeInfo
    let payDetails: PayDetails
    let allowances: [Allowance]
    let deductions: [Deduction]
    let netPay: NetPayInfo
    let bankDetails: BankInfo
    let period: PayPeriod
    let confidence: Float
    let extractionMetadata: ExtractionMetadata
}

struct EmployeeInfo: Codable {
    let employeeId: String
    let name: String
    let designation: String?
    let department: String?
    let payLevel: String?
    let panNumber: String?
    let serviceNumber: String?
}

struct PayDetails: Codable {
    let basicPay: Double
    let gradePay: Double?
    let totalEarnings: Double
    let totalDeductions: Double
    let netPay: Double
}

struct Allowance: Codable {
    let type: AllowanceType
    let description: String
    let amount: Double
    let isFixed: Bool
}

struct Deduction: Codable {
    let type: DeductionType
    let description: String
    let amount: Double
    let isStatutory: Bool
}

struct NetPayInfo: Codable {
    let grossPay: Double
    let totalDeductions: Double
    let netAmount: Double
    let amountInWords: String?
}

struct BankInfo: Codable {
    let bankName: String?
    let accountNumber: String?
    let branchCode: String?
    let ifscCode: String?
}

struct PayPeriod: Codable {
    let startDate: Date?
    let endDate: Date?
    let payMonth: String
    let payYear: String
}

struct ExtractionMetadata: Codable {
    let extractionDate: Date
    let templateUsed: String
    let confidence: Float
    let processingTime: TimeInterval
    let validationScore: Float
}

// MARK: - Allowance and Deduction Types

enum AllowanceType: String, CaseIterable, Codable {
    case dearnesAllowance = "DA"
    case houseRentAllowance = "HRA"
    case transportAllowance = "TA"
    case medicalAllowance = "MA"
    case cityCompensatoryAllowance = "CCA"
    case specialAllowance = "Special Allowance"
    case overtimeAllowance = "Overtime"
    case other = "Other"
    
    var displayName: String {
        switch self {
        case .dearnesAllowance:
            return "Dearness Allowance"
        case .houseRentAllowance:
            return "House Rent Allowance"
        case .transportAllowance:
            return "Transport Allowance"
        case .medicalAllowance:
            return "Medical Allowance"
        case .cityCompensatoryAllowance:
            return "City Compensatory Allowance"
        case .specialAllowance:
            return "Special Allowance"
        case .overtimeAllowance:
            return "Overtime Allowance"
        case .other:
            return "Other Allowance"
        }
    }
}

enum DeductionType: String, CaseIterable, Codable {
    case providentFund = "PF"
    case incomeTax = "Income Tax"
    case professionalTax = "Professional Tax"
    case lifeInsurance = "PLI"
    case loan = "Loan"
    case advance = "Advance"
    case canteenCharges = "Canteen"
    case other = "Other"
    
    var displayName: String {
        switch self {
        case .providentFund:
            return "Provident Fund"
        case .incomeTax:
            return "Income Tax"
        case .professionalTax:
            return "Professional Tax"
        case .lifeInsurance:
            return "Life Insurance (PLI)"
        case .loan:
            return "Loan Deduction"
        case .advance:
            return "Advance Recovery"
        case .canteenCharges:
            return "Canteen Charges"
        case .other:
            return "Other Deduction"
        }
    }
}

// MARK: - Military Payslip Field System

struct MilitaryPayslipField: Codable {
    let type: MilitaryPayslipFieldType
    let label: String
    let value: String
    let confidence: Float
    let source: FieldExtractionSource
    let isRequired: Bool
    
    var displayValue: String {
        return type.formatValue(value)
    }
}

enum MilitaryPayslipFieldType: String, CaseIterable, Codable {
    // Employee Information
    case employeeId = "employee_id"
    case employeeName = "employee_name"
    case designation = "designation"
    case department = "department"
    case payLevel = "pay_level"
    case panNumber = "pan_number"
    case serviceNumber = "service_number"
    
    // Financial Fields
    case basicPay = "basic_pay"
    case gradePay = "grade_pay"
    case totalEarnings = "total_earnings"
    case totalDeductions = "total_deductions"
    case netPay = "net_pay"
    
    // Allowances
    case da = "da"
    case hra = "hra"
    case transportAllowance = "transport_allowance"
    case medicalAllowance = "medical_allowance"
    
    // Deductions
    case providentFund = "provident_fund"
    case incomeTax = "income_tax"
    case lifeInsurance = "life_insurance"
    
    // Bank Details
    case bankName = "bank_name"
    case accountNumber = "account_number"
    case branchCode = "branch_code"
    case ifscCode = "ifsc_code"
    
    // Pay Period
    case payPeriod = "pay_period"
    case payMonth = "pay_month"
    case payYear = "pay_year"
    
    // Administrative
    case paoNumber = "pao_number"
    case susNumber = "sus_number"
    case billNumber = "bill_number"
    
    var defaultLabel: String {
        switch self {
        case .employeeId:
            return "Employee ID"
        case .employeeName:
            return "Employee Name"
        case .designation:
            return "Designation"
        case .department:
            return "Department"
        case .payLevel:
            return "Pay Level"
        case .panNumber:
            return "PAN Number"
        case .serviceNumber:
            return "Service Number"
        case .basicPay:
            return "Basic Pay"
        case .gradePay:
            return "Grade Pay"
        case .totalEarnings:
            return "Total Earnings"
        case .totalDeductions:
            return "Total Deductions"
        case .netPay:
            return "Net Pay"
        case .da:
            return "Dearness Allowance"
        case .hra:
            return "House Rent Allowance"
        case .transportAllowance:
            return "Transport Allowance"
        case .medicalAllowance:
            return "Medical Allowance"
        case .providentFund:
            return "Provident Fund"
        case .incomeTax:
            return "Income Tax"
        case .lifeInsurance:
            return "Life Insurance"
        case .bankName:
            return "Bank Name"
        case .accountNumber:
            return "Account Number"
        case .branchCode:
            return "Branch Code"
        case .ifscCode:
            return "IFSC Code"
        case .payPeriod:
            return "Pay Period"
        case .payMonth:
            return "Pay Month"
        case .payYear:
            return "Pay Year"
        case .paoNumber:
            return "PAO Number"
        case .susNumber:
            return "SUS Number"
        case .billNumber:
            return "Bill Number"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .employeeId, .employeeName, .basicPay, .netPay, .payPeriod:
            return true
        default:
            return false
        }
    }
    
    var category: FieldCategory {
        switch self {
        case .employeeId, .employeeName, .designation, .department, .payLevel, .panNumber, .serviceNumber:
            return .employeeInfo
        case .basicPay, .gradePay, .totalEarnings, .totalDeductions, .netPay:
            return .payDetails
        case .da, .hra, .transportAllowance, .medicalAllowance:
            return .allowances
        case .providentFund, .incomeTax, .lifeInsurance:
            return .deductions
        case .bankName, .accountNumber, .branchCode, .ifscCode:
            return .bankDetails
        case .payPeriod, .payMonth, .payYear:
            return .payPeriod
        case .paoNumber, .susNumber, .billNumber:
            return .administrative
        }
    }
    
    func formatValue(_ value: String) -> String {
        switch self.category {
        case .payDetails, .allowances, .deductions:
            // Format currency values
            if let numericValue = Double(value.replacingOccurrences(of: ",", with: "")) {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = "INR"
                formatter.currencySymbol = "₹"
                return formatter.string(from: NSNumber(value: numericValue)) ?? value
            }
            return value
        default:
            return value
        }
    }
}

enum FieldCategory: String, CaseIterable, Codable {
    case employeeInfo = "employee_info"
    case payDetails = "pay_details"
    case allowances = "allowances"
    case deductions = "deductions"
    case bankDetails = "bank_details"
    case payPeriod = "pay_period"
    case administrative = "administrative"
    
    var displayName: String {
        switch self {
        case .employeeInfo:
            return "Employee Information"
        case .payDetails:
            return "Pay Details"
        case .allowances:
            return "Allowances"
        case .deductions:
            return "Deductions"
        case .bankDetails:
            return "Bank Details"
        case .payPeriod:
            return "Pay Period"
        case .administrative:
            return "Administrative"
        }
    }
}

enum FieldExtractionSource: String, Codable {
    case patternMatching = "pattern_matching"
    case tableExtraction = "table_extraction"
    case sectionAnalysis = "section_analysis"
    case positionBased = "position_based"
    case manualEntry = "manual_entry"
    
    var displayName: String {
        switch self {
        case .patternMatching:
            return "Pattern Recognition"
        case .tableExtraction:
            return "Table Extraction"
        case .sectionAnalysis:
            return "Section Analysis"
        case .positionBased:
            return "Position Based"
        case .manualEntry:
            return "Manual Entry"
        }
    }
}

// MARK: - Template System

struct PayslipTemplate: Codable {
    let id: String
    let name: String
    let description: String
    let version: String
    let fieldTemplates: [FieldTemplate]
    let identificationPatterns: [String]
    let signatureFields: Set<MilitaryPayslipFieldType>
    let mandatoryFields: Set<MilitaryPayslipFieldType>
    let requiredSections: Set<PayslipSectionType>
    let minimumColumns: Int
    let minimumRows: Int
    let requiresHeader: Bool
    
    static func getAllTemplates() -> [PayslipTemplate] {
        return [
            getStandardMilitaryTemplate(),
            getOfficerPayslipTemplate(),
            getJuniorCommissionedOfficerTemplate()
        ]
    }
    
    static func getStandardMilitaryTemplate() -> PayslipTemplate {
        return PayslipTemplate(
            id: "military_standard_v1",
            name: "Standard Military Payslip",
            description: "Standard format used by most military units",
            version: "1.0",
            fieldTemplates: getStandardFieldTemplates(),
            identificationPatterns: [
                "EMPLOYEE\\s+ID",
                "PAO\\s*:?\\s*\\d+",
                "SUS\\s+NO",
                "CREDITS.*DEBITS",
                "AMOUNT\\s+CREDITED\\s+TO\\s+BANK"
            ],
            signatureFields: [.employeeId, .paoNumber, .susNumber],
            mandatoryFields: [.employeeId, .employeeName, .basicPay, .netPay, .payPeriod],
            requiredSections: [.header, .employeeInfo, .earnings, .deductions],
            minimumColumns: 2,
            minimumRows: 5,
            requiresHeader: true
        )
    }
    
    static func getOfficerPayslipTemplate() -> PayslipTemplate {
        return PayslipTemplate(
            id: "military_officer_v1",
            name: "Officer Payslip Template",
            description: "Template for commissioned officers",
            version: "1.0",
            fieldTemplates: getOfficerFieldTemplates(),
            identificationPatterns: [
                "OFFICER",
                "COMMISSION",
                "GRADE\\s+PAY",
                "LEVEL\\s*:?\\s*\\d+"
            ],
            signatureFields: [.employeeId, .payLevel, .gradePay],
            mandatoryFields: [.employeeId, .employeeName, .basicPay, .gradePay, .netPay],
            requiredSections: [.header, .employeeInfo, .earnings, .deductions],
            minimumColumns: 3,
            minimumRows: 8,
            requiresHeader: true
        )
    }
    
    static func getJuniorCommissionedOfficerTemplate() -> PayslipTemplate {
        return PayslipTemplate(
            id: "military_jco_v1",
            name: "JCO Payslip Template",
            description: "Template for Junior Commissioned Officers",
            version: "1.0",
            fieldTemplates: getJCOFieldTemplates(),
            identificationPatterns: [
                "JCO",
                "JUNIOR\\s+COMMISSIONED",
                "SUBEDAR",
                "NAIB\\s+SUBEDAR"
            ],
            signatureFields: [.employeeId, .serviceNumber, .designation],
            mandatoryFields: [.employeeId, .employeeName, .designation, .basicPay, .netPay],
            requiredSections: [.header, .employeeInfo, .earnings, .deductions],
            minimumColumns: 2,
            minimumRows: 6,
            requiresHeader: true
        )
    }
    
    private static func getStandardFieldTemplates() -> [FieldTemplate] {
        return [
            // Employee ID
            FieldTemplate(
                fieldType: .employeeId,
                patterns: [
                    "EMPLOYEE\\s+ID[.:\\s]*([0-9]+)",
                    "EMP\\s+ID[.:\\s]*([0-9]+)",
                    "ID\\s*:?\\s*([0-9]{5,8})"
                ],
                extractionStrategy: .patternBased,
                validationPatterns: ["^[0-9]{5,8}$"],
                isRequired: true,
                minLength: 5,
                maxLength: 8
            ),
            
            // Employee Name
            FieldTemplate(
                fieldType: .employeeName,
                patterns: [
                    "NAME[.:\\s]*([A-Z\\s]+)",
                    "EMPLOYEE\\s+NAME[.:\\s]*([A-Z\\s]+)"
                ],
                extractionStrategy: .patternBased,
                validationPatterns: ["^[A-Z\\s]{2,50}$"],
                isRequired: true,
                minLength: 2,
                maxLength: 50
            ),
            
            // Basic Pay
            FieldTemplate(
                fieldType: .basicPay,
                patterns: [
                    "BASIC\\s+PAY[.:\\s]*([0-9,]+)",
                    "GP-X\\s+PAY[.:\\s]*([0-9,]+)"
                ],
                extractionStrategy: .tableBased,
                validationPatterns: ["^[0-9,]{4,10}$"],
                isRequired: true,
                labelPattern: "BASIC\\s+PAY|GP-X\\s+PAY"
            ),
            
            // Net Pay
            FieldTemplate(
                fieldType: .netPay,
                patterns: [
                    "AMOUNT\\s+CREDITED\\s+TO\\s+BANK[.:\\s]*([0-9,]+)",
                    "NET\\s+PAY[.:\\s]*([0-9,]+)"
                ],
                extractionStrategy: .patternBased,
                validationPatterns: ["^[0-9,]{4,10}$"],
                isRequired: true
            ),
            
            // PAN Number
            FieldTemplate(
                fieldType: .panNumber,
                patterns: [
                    "PAN[.:\\s]*([A-Z]{5}[0-9]{4}[A-Z])"
                ],
                extractionStrategy: .patternBased,
                validationPatterns: ["^[A-Z]{5}[0-9]{4}[A-Z]$"],
                isRequired: false,
                minLength: 10,
                maxLength: 10
            )
        ]
    }
    
    private static func getOfficerFieldTemplates() -> [FieldTemplate] {
        var templates = getStandardFieldTemplates()
        
        // Add officer-specific templates
        templates.append(contentsOf: [
            FieldTemplate(
                fieldType: .gradePay,
                patterns: [
                    "GRADE\\s+PAY[.:\\s]*([0-9,]+)"
                ],
                extractionStrategy: .tableBased,
                validationPatterns: ["^[0-9,]{3,8}$"],
                isRequired: true,
                labelPattern: "GRADE\\s+PAY"
            ),
            
            FieldTemplate(
                fieldType: .payLevel,
                patterns: [
                    "PAY\\s+LEVEL[.:\\s]*([0-9]+)",
                    "LEVEL[.:\\s]*([0-9]+)"
                ],
                extractionStrategy: .sectionBased,
                validationPatterns: ["^[0-9]{1,2}$"],
                isRequired: false,
                targetSection: .employeeInfo
            )
        ])
        
        return templates
    }
    
    private static func getJCOFieldTemplates() -> [FieldTemplate] {
        var templates = getStandardFieldTemplates()
        
        // Add JCO-specific templates
        templates.append(contentsOf: [
            FieldTemplate(
                fieldType: .designation,
                patterns: [
                    "DESIGNATION[.:\\s]*([A-Z\\s]+)",
                    "(SUBEDAR|NAIB\\s+SUBEDAR|JCO)"
                ],
                extractionStrategy: .sectionBased,
                validationPatterns: ["^[A-Z\\s]{3,30}$"],
                isRequired: true,
                targetSection: .employeeInfo
            ),
            
            FieldTemplate(
                fieldType: .serviceNumber,
                patterns: [
                    "SERVICE\\s+NO[.:\\s]*([A-Z0-9/]+)",
                    "SVC\\s+NO[.:\\s]*([A-Z0-9/]+)"
                ],
                extractionStrategy: .patternBased,
                validationPatterns: ["^[A-Z0-9/]{8,15}$"],
                isRequired: false
            )
        ])
        
        return templates
    }
}

struct FieldTemplate: Codable {
    let fieldType: MilitaryPayslipFieldType
    let patterns: [String]
    let extractionStrategy: ExtractionStrategy
    let validationPatterns: [String]
    let isRequired: Bool
    let minLength: Int?
    let maxLength: Int?
    
    // Strategy-specific properties
    let targetSection: PayslipSectionType?
    let expectedPosition: FieldPosition?
    let labelPattern: String?
    
    init(fieldType: MilitaryPayslipFieldType,
         patterns: [String],
         extractionStrategy: ExtractionStrategy,
         validationPatterns: [String] = [],
         isRequired: Bool = false,
         minLength: Int? = nil,
         maxLength: Int? = nil,
         targetSection: PayslipSectionType? = nil,
         expectedPosition: FieldPosition? = nil,
         labelPattern: String? = nil) {
        
        self.fieldType = fieldType
        self.patterns = patterns
        self.extractionStrategy = extractionStrategy
        self.validationPatterns = validationPatterns
        self.isRequired = isRequired
        self.minLength = minLength
        self.maxLength = maxLength
        self.targetSection = targetSection
        self.expectedPosition = expectedPosition
        self.labelPattern = labelPattern
    }
}

struct FieldPosition: Codable {
    let bounds: CGRect
    let tolerance: CGFloat
    
    init(bounds: CGRect, tolerance: CGFloat = 10.0) {
        self.bounds = bounds
        self.tolerance = tolerance
    }
}

enum ExtractionStrategy: String, Codable {
    case patternBased = "pattern_based"
    case sectionBased = "section_based"
    case positionBased = "position_based"
    case tableBased = "table_based"
} 