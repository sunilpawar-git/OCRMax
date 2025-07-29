//
//  FormattingOptionsViewModelTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import XCTest
@testable import OCRMax

@MainActor
final class FormattingOptionsViewModelTests: XCTestCase {
    
    var viewModel: FormattingOptionsViewModel!
    var mockSubscriptionManager: MockSubscriptionManager!
    var mockAIFormattingService: MockAIFormattingService!
    
    override func setUp() {
        super.setUp()
        mockSubscriptionManager = MockSubscriptionManager()
        mockAIFormattingService = MockAIFormattingService()
        viewModel = FormattingOptionsViewModel(
            subscriptionManager: mockSubscriptionManager,
            aiFormattingService: mockAIFormattingService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockSubscriptionManager = nil
        mockAIFormattingService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(viewModel.selectedFormattingLevel, .basic)
        XCTAssertEqual(viewModel.estimatedAICost, 0.0)
        XCTAssertFalse(viewModel.showingUpgrade)
        XCTAssertFalse(viewModel.showingCostWarning)
    }
    
    // MARK: - Formatting Level Selection Tests
    
    func testSelectBasicFormatting() {
        viewModel.selectFormattingLevel(.basic)
        
        XCTAssertEqual(viewModel.selectedFormattingLevel, .basic)
        XCTAssertFalse(viewModel.showingUpgrade)
        XCTAssertEqual(viewModel.estimatedAICost, 0.0)
    }
    
    func testSelectEnhancedFormattingWithPremium() {
        mockSubscriptionManager.mockCurrentTier = .premium
        
        viewModel.selectFormattingLevel(.enhanced)
        
        XCTAssertEqual(viewModel.selectedFormattingLevel, .enhanced)
        XCTAssertFalse(viewModel.showingUpgrade)
    }
    
    func testSelectEnhancedFormattingWithoutPremium() {
        mockSubscriptionManager.mockCurrentTier = .free
        
        viewModel.selectFormattingLevel(.enhanced)
        
        XCTAssertEqual(viewModel.selectedFormattingLevel, .basic)
        XCTAssertTrue(viewModel.showingUpgrade)
    }
    
    // MARK: - Cost Estimation Tests
    
    func testAICostEstimation() {
        let sampleText = "This is a sample text for cost estimation"
        mockAIFormattingService.mockEstimatedCost = 0.15
        
        viewModel.updateTextForAICost(sampleText)
        
        XCTAssertEqual(viewModel.estimatedAICost, 0.15, accuracy: 0.01)
    }
    
    // MARK: - Premium Access Tests
    
    func testCanUseEnhancedFormatting() {
        mockSubscriptionManager.mockCurrentTier = .premium
        
        XCTAssertTrue(viewModel.canUseEnhancedFormatting)
        
        mockSubscriptionManager.mockCurrentTier = .free
        
        XCTAssertFalse(viewModel.canUseEnhancedFormatting)
    }
    
    func testCanUseAIFormatting() {
        mockSubscriptionManager.mockCurrentTier = .premium
        
        XCTAssertTrue(viewModel.canUseAIFormatting)
        
        mockSubscriptionManager.mockCurrentTier = .free
        
        XCTAssertFalse(viewModel.canUseAIFormatting)
    }
    
    // MARK: - Computed Properties Tests
    
    func testFormattingLevelDescription() {
        XCTAssertEqual(viewModel.formattingLevelDescription(.basic), "Standard OCR text extraction")
        XCTAssertEqual(viewModel.formattingLevelDescription(.enhanced), "Preserves document structure and layout")
        XCTAssertEqual(viewModel.formattingLevelDescription(.aiEnhanced), "AI-powered formatting with intelligent structure detection")
    }
    
    func testSubscriptionTierForFeature() {
        XCTAssertEqual(viewModel.subscriptionTierForFeature(.enhanced), .premium)
        XCTAssertEqual(viewModel.subscriptionTierForFeature(.aiEnhanced), .premium)
        XCTAssertNil(viewModel.subscriptionTierForFeature(.basic))
    }
}