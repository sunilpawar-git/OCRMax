//
//  SubscriptionViewModelTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import XCTest
@testable import OCRMax

@MainActor
final class SubscriptionViewModelTests: XCTestCase {
    
    var sut: SubscriptionViewModel!
    var mockSubscriptionManager: MockSubscriptionManager!
    
    override func setUp() {
        super.setUp()
        mockSubscriptionManager = MockSubscriptionManager()
        sut = SubscriptionViewModel(subscriptionManager: mockSubscriptionManager)
        // Reset call counts after initialization
        mockSubscriptionManager.reset()
    }
    
    override func tearDown() {
        sut = nil
        mockSubscriptionManager = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertFalse(sut.showingSubscriptionUpgrade)
        XCTAssertFalse(sut.showingFormattingOptions)
        XCTAssertFalse(sut.isProcessingPurchase)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - Computed Properties Tests
    
    func testIsPremiumUserWithFreeAccount() {
        mockSubscriptionManager.mockCurrentTier = .free
        XCTAssertFalse(sut.isPremiumUser)
    }
    
    func testIsPremiumUserWithPremiumAccount() {
        mockSubscriptionManager.mockCurrentTier = .premium
        XCTAssertTrue(sut.isPremiumUser)
    }
    
    func testCurrentTier() {
        mockSubscriptionManager.mockCurrentTier = .premium
        XCTAssertEqual(sut.currentTier, .premium)
        
        mockSubscriptionManager.mockCurrentTier = .free
        XCTAssertEqual(sut.currentTier, .free)
    }
    
    func testCanUseEnhancedFormattingWithFree() {
        mockSubscriptionManager.mockCurrentTier = .free
        XCTAssertFalse(sut.canUseEnhancedFormatting)
    }
    
    func testCanUseEnhancedFormattingWithPremium() {
        mockSubscriptionManager.mockCurrentTier = .premium
        XCTAssertTrue(sut.canUseEnhancedFormatting)
    }
    
    func testCanUseAIFormattingWithFree() {
        mockSubscriptionManager.mockCurrentTier = .free
        XCTAssertFalse(sut.canUseAIFormatting)
    }
    
    func testCanUseAIFormattingWithPremium() {
        mockSubscriptionManager.mockCurrentTier = .premium
        XCTAssertTrue(sut.canUseAIFormatting)
    }
    
    func testAvailableFormattingLevelsForFree() {
        mockSubscriptionManager.mockCurrentTier = .free
        let levels = sut.availableFormattingLevels
        XCTAssertEqual(levels.count, 1)
        XCTAssertTrue(levels.contains(.basic))
        XCTAssertFalse(levels.contains(.enhanced))
        XCTAssertFalse(levels.contains(.aiEnhanced))
    }
    
    func testAvailableFormattingLevelsForPremium() {
        mockSubscriptionManager.mockCurrentTier = .premium
        let levels = sut.availableFormattingLevels
        XCTAssertEqual(levels.count, 3)
        XCTAssertTrue(levels.contains(.basic))
        XCTAssertTrue(levels.contains(.enhanced))
        XCTAssertTrue(levels.contains(.aiEnhanced))
    }
    
    // MARK: - Purchase Flow Tests
    
    func testSuccessfulPremiumPurchase() async {
        mockSubscriptionManager.mockPurchaseSuccess = true
        mockSubscriptionManager.mockCurrentTier = .free
        
        sut.requestPremiumUpgrade(for: .premium)
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockSubscriptionManager.requestPurchaseCallCount, 1)
        XCTAssertEqual(mockSubscriptionManager.requestedTier, .premium)
        XCTAssertFalse(sut.showingSubscriptionUpgrade)
        XCTAssertFalse(sut.isProcessingPurchase)
        XCTAssertFalse(sut.showingError)
    }
    
    func testFailedPremiumPurchase() async {
        mockSubscriptionManager.mockPurchaseSuccess = false
        mockSubscriptionManager.mockError = OCRError.processingFailed
        
        sut.requestPremiumUpgrade(for: .premium)
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockSubscriptionManager.requestPurchaseCallCount, 1)
        XCTAssertFalse(sut.isProcessingPurchase)
        XCTAssertTrue(sut.showingError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testSuccessfulRestorePurchases() async {
        mockSubscriptionManager.mockRestoreSuccess = true
        
        sut.restorePurchases()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockSubscriptionManager.restorePurchasesCallCount, 1)
        XCTAssertFalse(sut.isProcessingPurchase)
        XCTAssertFalse(sut.showingError)
    }
    
    func testFailedRestorePurchases() async {
        mockSubscriptionManager.mockRestoreSuccess = false
        mockSubscriptionManager.mockError = OCRError.processingFailed
        
        sut.restorePurchases()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockSubscriptionManager.restorePurchasesCallCount, 1)
        XCTAssertFalse(sut.isProcessingPurchase)
        XCTAssertTrue(sut.showingError)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    // MARK: - UI State Tests
    
    func testShowSubscriptionUpgrade() {
        sut.showSubscriptionUpgrade()
        XCTAssertTrue(sut.showingSubscriptionUpgrade)
    }
    
    func testHideSubscriptionUpgrade() {
        sut.showingSubscriptionUpgrade = true
        sut.hideSubscriptionUpgrade()
        XCTAssertFalse(sut.showingSubscriptionUpgrade)
    }
    
    func testShowFormattingOptions() {
        sut.showFormattingOptions()
        XCTAssertTrue(sut.showingFormattingOptions)
    }
    
    func testHideFormattingOptions() {
        sut.showingFormattingOptions = true
        sut.hideFormattingOptions()
        XCTAssertFalse(sut.showingFormattingOptions)
    }
    
    // MARK: - Feature Gate Tests
    
    func testValidateFormattingLevelWithPremium() {
        mockSubscriptionManager.mockCurrentTier = .premium
        XCTAssertTrue(sut.validateFormattingLevel(.enhanced))
        XCTAssertFalse(sut.showingSubscriptionUpgrade)
    }
    
    func testValidateFormattingLevelWithoutPremium() {
        mockSubscriptionManager.mockCurrentTier = .free
        XCTAssertFalse(sut.validateFormattingLevel(.enhanced))
        XCTAssertTrue(sut.showingSubscriptionUpgrade)
    }
    
    func testCanUseFeature() {
        mockSubscriptionManager.mockCurrentTier = .premium
        XCTAssertTrue(sut.canUseFeature(.aiFormatting))
        
        mockSubscriptionManager.mockCurrentTier = .free
        XCTAssertFalse(sut.canUseFeature(.aiFormatting))
    }
    
    // MARK: - Status Check Tests
    
    func testCheckSubscriptionStatus() async {
        sut.checkSubscriptionStatus()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockSubscriptionManager.checkSubscriptionStatusCallCount, 1)
    }
    
    // MARK: - Computed Properties Tests
    
    func testSubscriptionStatusText() {
        mockSubscriptionManager.mockCurrentTier = .free
        XCTAssertEqual(sut.subscriptionStatusText, "Free Plan")
        
        mockSubscriptionManager.mockCurrentTier = .premium
        XCTAssertEqual(sut.subscriptionStatusText, "Premium Plan - All Features")
    }
    
    func testSubscriptionFeatures() {
        mockSubscriptionManager.mockCurrentTier = .free
        let freeFeatures = sut.subscriptionFeatures
        XCTAssertTrue(freeFeatures.contains("Basic OCR processing"))
        XCTAssertTrue(freeFeatures.contains("Text extraction"))
        
        mockSubscriptionManager.mockCurrentTier = .premium
        let premiumFeatures = sut.subscriptionFeatures
        XCTAssertTrue(premiumFeatures.contains("Enhanced layout analysis"))
        XCTAssertTrue(premiumFeatures.contains("AI-powered formatting"))
    }
} 