//
//  MockStoreKitService.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
@testable import OCRMax

enum StoreKitError: Error {
    case paymentCancelled
    case userCancelled
    case networkError
    case invalidProduct
}

class MockStoreKitService: StoreKitServiceProtocol {
    var mockSubscriptionStatus: SubscriptionTier = .free
    var shouldSucceedPurchase = true
    var shouldFailStatusCheck = false
    var isSubscriptionExpired = false
    var hasValidReceipt = true
    var purchaseRequested = false
    var requestedTier: SubscriptionTier?
    var purchaseError: Error?
    var statusCheckError: Error?
    var statusCheckAttempts = 0
    var receiptValidated = false
    var retryCount = 0
    var artificialDelay: TimeInterval = 0.0
    
    func checkSubscriptionStatus() async throws -> SubscriptionTier {
        statusCheckAttempts += 1
        
        // Add artificial delay if specified
        if artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(artificialDelay * 1_000_000_000))
        }
        
        // Handle retry logic
        if shouldFailStatusCheck && statusCheckAttempts <= retryCount {
            throw statusCheckError ?? URLError(.notConnectedToInternet)
        }
        
        // Reset failure flag after retries
        if statusCheckAttempts > retryCount {
            shouldFailStatusCheck = false
        }
        
        if shouldFailStatusCheck {
            throw statusCheckError ?? URLError(.notConnectedToInternet)
        }
        
        receiptValidated = hasValidReceipt
        
        if !hasValidReceipt {
            return .free
        }
        
        if isSubscriptionExpired {
            return .free
        }
        
        return mockSubscriptionStatus
    }
    
    func requestPurchase(for tier: SubscriptionTier) async throws -> Bool {
        purchaseRequested = true
        requestedTier = tier
        
        // Add artificial delay if specified
        if artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(artificialDelay * 1_000_000_000))
        }
        
        if !shouldSucceedPurchase {
            if let error = purchaseError {
                throw error
            } else {
                throw StoreKitError.paymentCancelled
            }
        }
        
        // Simulate successful purchase
        mockSubscriptionStatus = tier
        return true
    }
    
    func restorePurchases() async throws -> SubscriptionTier {
        receiptValidated = hasValidReceipt
        
        if !hasValidReceipt {
            return .free
        }
        
        return mockSubscriptionStatus
    }
    
    func validateReceipt() async throws -> Bool {
        receiptValidated = true
        return hasValidReceipt
    }
}