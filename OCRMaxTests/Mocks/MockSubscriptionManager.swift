//
//  MockSubscriptionManager.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
@testable import OCRMax

final class MockSubscriptionManager: SubscriptionManagerProtocol {
    
    private var _mockCurrentTier: SubscriptionTier = .free
    var mockCurrentTier: SubscriptionTier {
        get { return _mockCurrentTier }
        set { _mockCurrentTier = newValue }
    }
    
    var mockIsPremiumUser = false
    var mockError: Error?
    var mockPurchaseSuccess = true
    var mockRestoreSuccess = true
    
    var checkSubscriptionStatusCallCount = 0
    var canUseFeatureCallCount = 0
    var requestPurchaseCallCount = 0
    var restorePurchasesCallCount = 0
    
    var requestPurchaseCalled = false
    var restorePurchasesCalled = false
    var requestedTier: SubscriptionTier?
    var lastQueriedFeature: PremiumFeature?
    
    var isPremiumUser: Bool {
        return _mockCurrentTier != .free
    }
    
    var currentTier: SubscriptionTier {
        return _mockCurrentTier
    }
    
    func checkSubscriptionStatus() async {
        checkSubscriptionStatusCallCount += 1
    }
    
    func canUseFeature(_ feature: PremiumFeature) -> Bool {
        canUseFeatureCallCount += 1
        lastQueriedFeature = feature
        
        // Updated for simplified model: premium tier can use all features
        switch _mockCurrentTier {
        case .free:
            return false
        case .premium:
            return true
        }
    }
    
    func requestPurchase(for tier: SubscriptionTier) async throws -> Bool {
        requestPurchaseCallCount += 1
        requestPurchaseCalled = true
        requestedTier = tier
        
        if let error = mockError {
            throw error
        }
        
        if mockPurchaseSuccess {
            _mockCurrentTier = tier
        }
        
        return mockPurchaseSuccess
    }
    
    func restorePurchases() async throws -> Bool {
        restorePurchasesCallCount += 1
        restorePurchasesCalled = true
        
        if let error = mockError {
            throw error
        }
        
        if mockRestoreSuccess {
            _mockCurrentTier = .premium
            return true
        }
        
        return false
    }
    
    func reset() {
        _mockCurrentTier = .free
        mockIsPremiumUser = false
        mockError = nil
        mockPurchaseSuccess = true
        mockRestoreSuccess = true
        
        checkSubscriptionStatusCallCount = 0
        canUseFeatureCallCount = 0
        requestPurchaseCallCount = 0
        restorePurchasesCallCount = 0
        
        requestPurchaseCalled = false
        restorePurchasesCalled = false
        requestedTier = nil
        lastQueriedFeature = nil
    }
}