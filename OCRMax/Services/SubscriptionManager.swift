//
//  SubscriptionManager.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
import StoreKit

final class SubscriptionManager: SubscriptionManagerProtocol, ObservableObject {
    
    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var isLoading = false
    
    private let storeKitService: StoreKitServiceProtocol
    private let userDefaults: UserDefaults
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    private var lastStatusCheck: Date?
    private var statusCheckTask: Task<Void, Never>?
    
    var isPremiumUser: Bool {
        currentTier != .free
    }
    
    init(storeKitService: StoreKitServiceProtocol = StoreKitService(),
         userDefaults: UserDefaults = .standard,
         currentTier: SubscriptionTier = .free) {
        self.storeKitService = storeKitService
        self.userDefaults = userDefaults
        self.currentTier = currentTier
        
        loadCachedSubscriptionStatus()
    }
    
    convenience init(currentTier: SubscriptionTier) {
        self.init(storeKitService: StoreKitService(), currentTier: currentTier)
    }
    
    deinit {
        statusCheckTask?.cancel()
    }
    
    // MARK: - SubscriptionManagerProtocol
    
    func checkSubscriptionStatus() async {
        await checkSubscriptionStatus(forceRefresh: false)
    }
    
    func checkSubscriptionStatus(forceRefresh: Bool = false) async {
        // Prevent multiple concurrent status checks
        if let existingTask = statusCheckTask, !existingTask.isCancelled {
            await existingTask.value
            return
        }
        
        // Check cache first
        if !forceRefresh && !shouldRefreshStatus() {
            return
        }
        
        statusCheckTask = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                let tier = try await storeKitService.checkSubscriptionStatus()
                updateSubscriptionTier(tier)
                lastStatusCheck = Date()
                cacheSubscriptionStatus()
            } catch {
                print("Failed to check subscription status: \(error)")
                // Keep current status on error
            }
        }
        
        await statusCheckTask?.value
    }
    
    func canUseFeature(_ feature: PremiumFeature) -> Bool {
        switch currentTier {
        case .free:
            return false
        case .pro:
            return [.aiFormatting, .enhancedLayout].contains(feature)
        case .proPlus:
            return true // All features available
        }
    }
    
    func requestPurchase(for tier: SubscriptionTier) async throws -> Bool {
        guard tier != .free else {
            throw OCRError.unsupportedFormat
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await storeKitService.requestPurchase(for: tier)
            if success {
                await updateSubscriptionTier(tier)
                cacheSubscriptionStatus()
            }
            return success
        } catch {
            throw error
        }
    }
    
    func restorePurchases() async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        let tier = try await storeKitService.restorePurchases()
        let wasRestored = tier != .free
        await updateSubscriptionTier(tier)
        cacheSubscriptionStatus()
        return wasRestored
    }
    
    func getFeatureList(for tier: SubscriptionTier) -> [PremiumFeature] {
        switch tier {
        case .free:
            return []
        case .pro:
            return [.aiFormatting, .enhancedLayout]
        case .proPlus:
            return PremiumFeature.allCases
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func updateSubscriptionTier(_ tier: SubscriptionTier) {
        currentTier = tier
    }
    
    private func shouldRefreshStatus() -> Bool {
        guard let lastCheck = lastStatusCheck else { return true }
        return Date().timeIntervalSince(lastCheck) > cacheExpirationInterval
    }
    
    private func loadCachedSubscriptionStatus() {
        if let cachedTierString = userDefaults.string(forKey: "subscription_tier"),
           let cachedTier = SubscriptionTier(rawValue: cachedTierString) {
            currentTier = cachedTier
        }
        
        if let cachedDate = userDefaults.object(forKey: "last_status_check") as? Date {
            lastStatusCheck = cachedDate
        }
    }
    
    private func cacheSubscriptionStatus() {
        userDefaults.set(currentTier.rawValue, forKey: "subscription_tier")
        userDefaults.set(lastStatusCheck, forKey: "last_status_check")
    }
}

// MARK: - StoreKit Service Protocol

protocol StoreKitServiceProtocol {
    func checkSubscriptionStatus() async throws -> SubscriptionTier
    func requestPurchase(for tier: SubscriptionTier) async throws -> Bool
    func restorePurchases() async throws -> SubscriptionTier
}

// MARK: - Real StoreKit Implementation

final class StoreKitService: StoreKitServiceProtocol {
    
    private let productIdentifiers: [SubscriptionTier: String] = [
        .pro: "com.ocrmax.pro.monthly",
        .proPlus: "com.ocrmax.proplus.monthly"
    ]
    
    func checkSubscriptionStatus() async throws -> SubscriptionTier {
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if let tier = productIdentifiers.first(where: { $0.value == transaction.productID })?.key {
                    // Verify transaction is still valid
                    if transaction.expirationDate == nil || transaction.expirationDate! > Date() {
                        return tier
                    }
                }
            } catch {
                print("Failed to verify transaction: \(error)")
                continue
            }
        }
        
        return .free
    }
    
    func requestPurchase(for tier: SubscriptionTier) async throws -> Bool {
        guard let productId = productIdentifiers[tier] else {
            throw OCRError.unsupportedFormat
        }
        
        // Request products from App Store
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            throw OCRError.unsupportedFormat
        }
        
        // Start the purchase
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            // Transaction is pending external action (e.g., Ask to Buy)
            return false
            
        @unknown default:
            return false
        }
    }
    
    func restorePurchases() async throws -> SubscriptionTier {
        try await AppStore.sync()
        return try await checkSubscriptionStatus()
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw OCRError.processingFailed
        case .verified(let safe):
            return safe
        }
    }
}