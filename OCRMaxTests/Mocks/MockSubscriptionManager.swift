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
    
    var checkSubscriptionStatusCallCount = 0
    var canUseFeatureCallCount = 0
    var requestPurchaseCallCount = 0
    
    var requestPurchaseCalled = false
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
        
        switch feature {
        case .enhancedLayout:
            return _mockCurrentTier == .pro || _mockCurrentTier == .proPlus
        case .aiFormatting:
            return _mockCurrentTier == .proPlus
        case .batchProcessing:
            return _mockCurrentTier == .pro || _mockCurrentTier == .proPlus
        case .prioritySupport:
            return _mockCurrentTier == .proPlus
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
    
    func reset() {
        _mockCurrentTier = .free
        mockIsPremiumUser = false
        mockError = nil
        mockPurchaseSuccess = true
        
        checkSubscriptionStatusCallCount = 0
        canUseFeatureCallCount = 0
        requestPurchaseCallCount = 0
        
        requestPurchaseCalled = false
        requestedTier = nil
        lastQueriedFeature = nil
    }
}