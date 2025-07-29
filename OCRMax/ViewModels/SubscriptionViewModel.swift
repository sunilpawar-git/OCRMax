//
//  SubscriptionViewModel.swift
//  OCRMax
//
//  Created by Sunil Pawar on 29/07/25.
//

import Foundation
import SwiftUI

@MainActor
final class SubscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var showingSubscriptionUpgrade = false
    @Published var showingFormattingOptions = false
    @Published var isProcessingPurchase = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Dependencies
    private let subscriptionManager: SubscriptionManagerProtocol
    
    // MARK: - Computed Properties
    var isPremiumUser: Bool {
        return subscriptionManager.isPremiumUser
    }
    
    var currentTier: SubscriptionTier {
        return subscriptionManager.currentTier
    }
    
    var canUseEnhancedFormatting: Bool {
        return subscriptionManager.canUseFeature(.enhancedLayout)
    }
    
    var canUseAIFormatting: Bool {
        return subscriptionManager.canUseFeature(.aiFormatting)
    }
    
    var availableFormattingLevels: [FormattingLevel] {
        var levels: [FormattingLevel] = [.basic]
        
        if canUseEnhancedFormatting {
            levels.append(.enhanced)
        }
        
        if canUseAIFormatting {
            levels.append(.aiEnhanced)
        }
        
        return levels
    }
    
    // MARK: - Initialization
    init(subscriptionManager: SubscriptionManagerProtocol = SubscriptionManager()) {
        self.subscriptionManager = subscriptionManager
        checkSubscriptionStatus()
    }
    
    // MARK: - Public Methods
    func checkSubscriptionStatus() {
        Task {
            await subscriptionManager.checkSubscriptionStatus()
        }
    }
    
    func requestPremiumUpgrade(for tier: SubscriptionTier) {
        guard !isProcessingPurchase else { return }
        
        isProcessingPurchase = true
        
        Task {
            do {
                let success = try await subscriptionManager.requestPurchase(for: tier)
                isProcessingPurchase = false
                
                if success {
                    showingSubscriptionUpgrade = false
                    checkSubscriptionStatus()
                }
            } catch {
                isProcessingPurchase = false
                handleError(error)
            }
        }
    }
    
    func restorePurchases() {
        guard !isProcessingPurchase else { return }
        
        isProcessingPurchase = true
        
        Task {
            do {
                let success = try await subscriptionManager.restorePurchases()
                isProcessingPurchase = false
                
                if success {
                    checkSubscriptionStatus()
                }
            } catch {
                isProcessingPurchase = false
                handleError(error)
            }
        }
    }
    
    func validateFormattingLevel(_ level: FormattingLevel) -> Bool {
        if level.requiresPremium && !isPremiumUser {
            showingSubscriptionUpgrade = true
            return false
        }
        return true
    }
    
    func canUseFeature(_ feature: PremiumFeature) -> Bool {
        return subscriptionManager.canUseFeature(feature)
    }
    
    func showFormattingOptions() {
        showingFormattingOptions = true
    }
    
    func hideFormattingOptions() {
        showingFormattingOptions = false
    }
    
    func showSubscriptionUpgrade() {
        showingSubscriptionUpgrade = true
    }
    
    func hideSubscriptionUpgrade() {
        showingSubscriptionUpgrade = false
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error) {
        if let ocrError = error as? OCRError {
            errorMessage = ocrError.localizedDescription
        } else {
            errorMessage = "Subscription error: \(error.localizedDescription)"
        }
        
        showingError = true
    }
}

// MARK: - Computed Properties
extension SubscriptionViewModel {
    var subscriptionStatusText: String {
        switch currentTier {
        case .free:
            return "Free Plan"
        case .premium:
            return "Premium Plan - All Features"
        }
    }
    
    var subscriptionFeatures: [String] {
        switch currentTier {
        case .free:
            return ["Basic OCR processing", "Text extraction", "RTF export"]
        case .premium:
            return ["Enhanced layout analysis", "AI-powered formatting", "Spatial formatting", "Advanced export options", "Premium support"]
        }
    }
}