//
//  SubscriptionManagerTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import XCTest
import StoreKit
@testable import OCRMax

final class SubscriptionManagerTests: XCTestCase {
    
    var subscriptionManager: SubscriptionManager!
    var mockStoreKit: MockStoreKitService!
    
    override func setUp() {
        super.setUp()
        mockStoreKit = MockStoreKitService()
        mockStoreKit.reset()
        subscriptionManager = SubscriptionManager(storeKitService: mockStoreKit)
    }
    
    override func tearDown() {
        subscriptionManager = nil
        mockStoreKit = nil
        super.tearDown()
    }
    
    // MARK: - Subscription Status Tests
    
    func testDefaultFreeSubscription() {
        XCTAssertFalse(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    func testPremiumSubscriptionStatus() async {
        mockStoreKit.mockSubscriptionStatus = .premium
        
        await subscriptionManager.checkSubscriptionStatus()
        
        XCTAssertTrue(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .premium)
    }
    
    func testExpiredSubscriptionHandling() async {
        mockStoreKit.mockSubscriptionStatus = .premium
        mockStoreKit.isSubscriptionExpired = true
        
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertFalse(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    // MARK: - Feature Access Tests
    
    func testFreeUserFeatureAccess() async {
        mockStoreKit.mockSubscriptionStatus = .free
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertFalse(subscriptionManager.canUseFeature(.aiFormatting))
        XCTAssertFalse(subscriptionManager.canUseFeature(.enhancedLayout))
    }
    
    func testPremiumUserFeatureAccess() async {
        mockStoreKit.mockSubscriptionStatus = .premium
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertTrue(subscriptionManager.canUseFeature(.aiFormatting))
        XCTAssertTrue(subscriptionManager.canUseFeature(.enhancedLayout))
    }
    
    // MARK: - Purchase Flow Tests
    
    func testSuccessfulPremiumPurchase() async throws {
        mockStoreKit.shouldSucceedPurchase = true
        mockStoreKit.mockSubscriptionStatus = .premium
        
        let success = try await subscriptionManager.requestPurchase(for: .premium)
        
        XCTAssertTrue(success)
        XCTAssertTrue(mockStoreKit.purchaseRequested)
        XCTAssertEqual(mockStoreKit.requestedTier, .premium)
    }
    
    func testFailedPurchase() async {
        mockStoreKit.shouldSucceedPurchase = false
        mockStoreKit.purchaseError = StoreKitError.paymentCancelled
        
        do {
            _ = try await subscriptionManager.requestPurchase(for: .premium)
            XCTFail("Should have thrown an error")
        } catch StoreKitError.paymentCancelled {
            // Expected behavior
            XCTAssertTrue(mockStoreKit.purchaseRequested)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testCancelledPurchase() async {
        mockStoreKit.shouldSucceedPurchase = false
        mockStoreKit.purchaseError = StoreKitError.userCancelled
        
        do {
            _ = try await subscriptionManager.requestPurchase(for: .premium)
            XCTFail("Should have thrown an error")
        } catch StoreKitError.userCancelled {
            // Expected behavior
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Restore Purchases Tests
    
    func testSuccessfulRestorePurchases() async throws {
        mockStoreKit.mockSubscriptionStatus = .premium
        mockStoreKit.hasValidReceipt = true
        
        let success = try await subscriptionManager.restorePurchases()
        
        XCTAssertTrue(success)
        XCTAssertTrue(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .premium)
    }
    
    func testFailedRestorePurchases() async throws {
        mockStoreKit.mockSubscriptionStatus = .free
        mockStoreKit.hasValidReceipt = false
        
        let success = try await subscriptionManager.restorePurchases()
        
        XCTAssertFalse(success)
        XCTAssertFalse(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    // MARK: - Network Error Handling Tests
    
    func testNetworkErrorHandling() async {
        // First set up initial state
        mockStoreKit.mockSubscriptionStatus = .premium
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        XCTAssertEqual(subscriptionManager.currentTier, .premium)
        
        // Now simulate network error
        mockStoreKit.shouldFailStatusCheck = true
        mockStoreKit.statusCheckError = URLError(.notConnectedToInternet)
        
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        // Should maintain current status on network error
        XCTAssertEqual(subscriptionManager.currentTier, .premium)
    }
    
    func testRetryLogicOnFailure() async {
        mockStoreKit.shouldFailStatusCheck = true
        mockStoreKit.retryCount = 2 // Fail first 2 attempts, succeed on 3rd
        mockStoreKit.mockSubscriptionStatus = .premium
        
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 3)
    }
    
    // MARK: - Subscription Validation Tests
    
    func testReceiptValidation() async {
        mockStoreKit.hasValidReceipt = true
        mockStoreKit.mockSubscriptionStatus = .premium
        
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertTrue(subscriptionManager.isPremiumUser)
        XCTAssertTrue(mockStoreKit.receiptValidated)
    }
    
    func testInvalidReceiptHandling() async {
        mockStoreKit.hasValidReceipt = false
        mockStoreKit.mockSubscriptionStatus = .premium
        
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertFalse(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    // MARK: - Subscription Downgrade Tests
    
    func testDowngradeHandling() async {
        mockStoreKit.mockSubscriptionStatus = .premium
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        XCTAssertEqual(subscriptionManager.currentTier, .premium)
        
        // Simulate subscription expiration
        mockStoreKit.mockSubscriptionStatus = .free
        mockStoreKit.isSubscriptionExpired = true
        
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    // MARK: - Cache and Performance Tests
    
    func testSubscriptionStatusCaching() async {
        mockStoreKit.mockSubscriptionStatus = .premium
        
        // First check should hit the network
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 1)
        
        // Second check within cache period should not hit network
        await subscriptionManager.checkSubscriptionStatus()
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 1) // Still 1, not 2
    }
    
    func testForcedRefresh() async {
        mockStoreKit.mockSubscriptionStatus = .premium
        
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 2)
    }
    
    // MARK: - Edge Cases Tests
    
    func testMultipleConcurrentStatusChecks() async {
        mockStoreKit.mockSubscriptionStatus = .premium
        mockStoreKit.artificialDelay = 0.1 // Add small delay to simulate network
        
        // Start multiple concurrent status checks - only first one forces refresh
        async let check1 = subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        async let check2 = subscriptionManager.checkSubscriptionStatus()
        async let check3 = subscriptionManager.checkSubscriptionStatus()
        
        await check1
        await check2 
        await check3
        
        // Should only make one network call due to request deduplication
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 1)
    }
    
    func testSubscriptionManagerMemoryManagement() {
        weak var weakManager = subscriptionManager
        subscriptionManager = nil
        
        XCTAssertNil(weakManager, "SubscriptionManager should be deallocated")
    }
    
    // MARK: - Feature List Tests
    
    func testFeatureListForFree() {
        let features = subscriptionManager.getFeatureList(for: .free)
        XCTAssertEqual(features.count, 0)
    }
    
    func testFeatureListForPremium() {
        let features = subscriptionManager.getFeatureList(for: .premium)
        XCTAssertEqual(features.count, PremiumFeature.allCases.count)
        XCTAssertTrue(features.contains(.aiFormatting))
        XCTAssertTrue(features.contains(.enhancedLayout))
    }
}