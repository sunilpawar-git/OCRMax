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
    
    func testProSubscriptionStatus() async {
        mockStoreKit.mockSubscriptionStatus = .pro
        
        await subscriptionManager.checkSubscriptionStatus()
        
        XCTAssertTrue(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .pro)
    }
    
    func testProPlusSubscriptionStatus() async {
        mockStoreKit.mockSubscriptionStatus = .proPlus
        
        await subscriptionManager.checkSubscriptionStatus()
        
        XCTAssertTrue(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .proPlus)
    }
    
    func testExpiredSubscriptionHandling() async {
        mockStoreKit.mockSubscriptionStatus = .free
        mockStoreKit.isSubscriptionExpired = true
        
        await subscriptionManager.checkSubscriptionStatus()
        
        XCTAssertFalse(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    // MARK: - Feature Access Tests
    
    func testFreeUserFeatureAccess() {
        subscriptionManager = SubscriptionManager(currentTier: .free)
        
        XCTAssertFalse(subscriptionManager.canUseFeature(.aiFormatting))
        XCTAssertFalse(subscriptionManager.canUseFeature(.enhancedLayout))
        XCTAssertFalse(subscriptionManager.canUseFeature(.batchProcessing))
        XCTAssertFalse(subscriptionManager.canUseFeature(.prioritySupport))
    }
    
    func testProUserFeatureAccess() {
        subscriptionManager = SubscriptionManager(currentTier: .pro)
        
        XCTAssertTrue(subscriptionManager.canUseFeature(.aiFormatting))
        XCTAssertTrue(subscriptionManager.canUseFeature(.enhancedLayout))
        XCTAssertFalse(subscriptionManager.canUseFeature(.batchProcessing))
        XCTAssertFalse(subscriptionManager.canUseFeature(.prioritySupport))
    }
    
    func testProPlusUserFeatureAccess() {
        subscriptionManager = SubscriptionManager(currentTier: .proPlus)
        
        XCTAssertTrue(subscriptionManager.canUseFeature(.aiFormatting))
        XCTAssertTrue(subscriptionManager.canUseFeature(.enhancedLayout))
        XCTAssertTrue(subscriptionManager.canUseFeature(.batchProcessing))
        XCTAssertTrue(subscriptionManager.canUseFeature(.prioritySupport))
    }
    
    // MARK: - Purchase Flow Tests
    
    func testSuccessfulProPurchase() async throws {
        mockStoreKit.shouldSucceedPurchase = true
        mockStoreKit.mockSubscriptionStatus = .pro
        
        let success = try await subscriptionManager.requestPurchase(for: .pro)
        
        XCTAssertTrue(success)
        XCTAssertTrue(mockStoreKit.purchaseRequested)
        XCTAssertEqual(mockStoreKit.requestedTier, .pro)
    }
    
    func testSuccessfulProPlusPurchase() async throws {
        mockStoreKit.shouldSucceedPurchase = true
        mockStoreKit.mockSubscriptionStatus = .proPlus
        
        let success = try await subscriptionManager.requestPurchase(for: .proPlus)
        
        XCTAssertTrue(success)
        XCTAssertTrue(mockStoreKit.purchaseRequested)
        XCTAssertEqual(mockStoreKit.requestedTier, .proPlus)
    }
    
    func testFailedPurchase() async {
        mockStoreKit.shouldSucceedPurchase = false
        mockStoreKit.purchaseError = StoreKitError.paymentCancelled
        
        do {
            _ = try await subscriptionManager.requestPurchase(for: .pro)
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
            _ = try await subscriptionManager.requestPurchase(for: .proPlus)
            XCTFail("Should have thrown an error")
        } catch StoreKitError.userCancelled {
            // Expected behavior
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Network Error Handling Tests
    
    func testNetworkErrorHandling() async {
        mockStoreKit.shouldFailStatusCheck = true
        mockStoreKit.statusCheckError = URLError(.notConnectedToInternet)
        
        await subscriptionManager.checkSubscriptionStatus()
        
        // Should maintain current status on network error
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    func testRetryLogicOnFailure() async {
        mockStoreKit.shouldFailStatusCheck = true
        mockStoreKit.retryCount = 2 // Fail first 2 attempts, succeed on 3rd
        
        await subscriptionManager.checkSubscriptionStatus()
        
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 3)
    }
    
    // MARK: - Subscription Validation Tests
    
    func testReceiptValidation() async {
        mockStoreKit.hasValidReceipt = true
        mockStoreKit.mockSubscriptionStatus = .pro
        
        await subscriptionManager.checkSubscriptionStatus()
        
        XCTAssertTrue(subscriptionManager.isPremiumUser)
        XCTAssertTrue(mockStoreKit.receiptValidated)
    }
    
    func testInvalidReceiptHandling() async {
        mockStoreKit.hasValidReceipt = false
        mockStoreKit.mockSubscriptionStatus = .pro
        
        await subscriptionManager.checkSubscriptionStatus()
        
        XCTAssertFalse(subscriptionManager.isPremiumUser)
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    // MARK: - Subscription Tier Upgrade/Downgrade Tests
    
    func testUpgradeFromProToProPlus() async throws {
        subscriptionManager = SubscriptionManager(currentTier: .pro)
        mockStoreKit.shouldSucceedPurchase = true
        mockStoreKit.mockSubscriptionStatus = .proPlus
        
        let success = try await subscriptionManager.requestPurchase(for: .proPlus)
        
        XCTAssertTrue(success)
        await subscriptionManager.checkSubscriptionStatus()
        XCTAssertEqual(subscriptionManager.currentTier, .proPlus)
    }
    
    func testDowngradeHandling() async {
        mockStoreKit.mockSubscriptionStatus = .pro
        await subscriptionManager.checkSubscriptionStatus()
        XCTAssertEqual(subscriptionManager.currentTier, .pro)
        
        // Simulate subscription expiration
        mockStoreKit.mockSubscriptionStatus = .free
        mockStoreKit.isSubscriptionExpired = true
        
        await subscriptionManager.checkSubscriptionStatus()
        XCTAssertEqual(subscriptionManager.currentTier, .free)
    }
    
    // MARK: - Cache and Performance Tests
    
    func testSubscriptionStatusCaching() async {
        mockStoreKit.mockSubscriptionStatus = .pro
        
        // First check should hit the network
        await subscriptionManager.checkSubscriptionStatus()
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 1)
        
        // Second check within cache period should not hit network
        await subscriptionManager.checkSubscriptionStatus()
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 1) // Still 1, not 2
    }
    
    func testForcedRefresh() async {
        mockStoreKit.mockSubscriptionStatus = .pro
        
        await subscriptionManager.checkSubscriptionStatus()
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true)
        
        XCTAssertEqual(mockStoreKit.statusCheckAttempts, 2)
    }
    
    // MARK: - Edge Cases Tests
    
    func testMultipleConcurrentStatusChecks() async {
        mockStoreKit.mockSubscriptionStatus = .pro
        mockStoreKit.artificialDelay = 0.1 // Add small delay to simulate network
        
        // Start multiple concurrent status checks
        async let check1 = subscriptionManager.checkSubscriptionStatus()
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
}