//
//  FormattingOptionsViewModel.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import Foundation
import SwiftUI

@MainActor
final class FormattingOptionsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedFormattingLevel: FormattingLevel = .basic
    @Published var estimatedAICost: Double = 0.0
    @Published var showingUpgrade = false
    @Published var showingCostWarning = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let subscriptionManager: SubscriptionManagerProtocol
    private let aiFormattingService: AIFormattingServiceProtocol
    
    // MARK: - Constants
    private let costWarningThreshold: Double = 1.0
    
    // MARK: - Initialization
    init(subscriptionManager: SubscriptionManagerProtocol = SubscriptionManager(),
         aiFormattingService: AIFormattingServiceProtocol = AIFormattingService(subscriptionManager: SubscriptionManager())) {
        self.subscriptionManager = subscriptionManager
        self.aiFormattingService = aiFormattingService
    }
    
    // MARK: - Computed Properties
    
    var canUseEnhancedFormatting: Bool {
        return subscriptionManager.canUseFeature(.enhancedLayout)
    }
    
    var canUseAIFormatting: Bool {
        return subscriptionManager.canUseFeature(.aiFormatting)
    }
    
    var currentSubscriptionTier: SubscriptionTier {
        return subscriptionManager.currentTier
    }
    
    var availableFormattingLevels: [FormattingLevel] {
        return FormattingLevel.allCases
    }
    
    // MARK: - Public Methods
    
    func selectFormattingLevel(_ level: FormattingLevel) {
        // Check if user has access to the selected formatting level
        switch level {
        case .basic:
            selectedFormattingLevel = level
            estimatedAICost = 0.0
            showingCostWarning = false
            
        case .enhanced:
            if canUseEnhancedFormatting {
                selectedFormattingLevel = level
                estimatedAICost = 0.0
                showingCostWarning = false
            } else {
                showingUpgrade = true
            }
            
        case .aiEnhanced:
            if canUseAIFormatting {
                selectedFormattingLevel = level
                checkCostWarning()
            } else {
                showingUpgrade = true
            }
        }
    }
    
    func updateTextForAICost(_ text: String) {
        guard !text.isEmpty else {
            estimatedAICost = 0.0
            return
        }
        
        estimatedAICost = aiFormattingService.estimatedCost(for: text)
    }
    
    func requestUpgrade(to tier: SubscriptionTier) async {
        do {
            let success = try await subscriptionManager.requestPurchase(for: tier)
            if success {
                showingUpgrade = false
                // Refresh subscription status and try selecting the formatting level again
                await subscriptionManager.checkSubscriptionStatus()
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    func dismissUpgradeDialog() {
        showingUpgrade = false
    }
    
    func dismissCostWarning() {
        showingCostWarning = false
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Helper Methods
    
    func formattingLevelDescription(_ level: FormattingLevel) -> String {
        switch level {
        case .basic:
            return "Standard OCR text extraction"
        case .enhanced:
            return "Preserves document structure and layout"
        case .aiEnhanced:
            return "AI-powered formatting with intelligent structure detection"
        }
    }
    
    func subscriptionTierForFeature(_ level: FormattingLevel) -> SubscriptionTier? {
        switch level {
        case .basic:
            return nil
        case .enhanced:
            return .pro
        case .aiEnhanced:
            return .proPlus
        }
    }
    
    func formattingLevelIcon(_ level: FormattingLevel) -> String {
        switch level {
        case .basic:
            return "doc.text"
        case .enhanced:
            return "doc.richtext"
        case .aiEnhanced:
            return "brain.head.profile"
        }
    }
    
    func isFormattingLevelEnabled(_ level: FormattingLevel) -> Bool {
        switch level {
        case .basic:
            return true
        case .enhanced:
            return canUseEnhancedFormatting
        case .aiEnhanced:
            return canUseAIFormatting
        }
    }
    
    func formattingLevelBadgeText(_ level: FormattingLevel) -> String? {
        if level.requiresPremium && !isFormattingLevelEnabled(level) {
            return subscriptionTierForFeature(level)?.displayName
        }
        return nil
    }
    
    func costDisplayText() -> String {
        if estimatedAICost > 0 {
            return String(format: "Estimated cost: $%.2f", estimatedAICost)
        }
        return ""
    }
    
    func upgradeMessage(for level: FormattingLevel) -> String {
        guard let requiredTier = subscriptionTierForFeature(level) else {
            return ""
        }
        
        let featureName = level == .enhanced ? "Enhanced Layout" : "AI Formatting"
        return "\(featureName) requires \(requiredTier.displayName) subscription ($\(String(format: "%.2f", requiredTier.monthlyPrice))/month)"
    }
    
    // MARK: - Private Methods
    
    private func checkCostWarning() {
        if estimatedAICost > costWarningThreshold {
            showingCostWarning = true
        } else {
            showingCostWarning = false
        }
    }
}

// MARK: - FormattingLevel Extension
extension FormattingLevel {
    var detailedDescription: String {
        switch self {
        case .basic:
            return "Extracts text as-is without formatting preservation. Free for all users."
        case .enhanced:
            return "Analyzes document structure to preserve headers, paragraphs, columns, and spacing. Requires Pro subscription."
        case .aiEnhanced:
            return "Uses AI to intelligently format text with proper structure, styling, and layout optimization. Requires Pro+ subscription and incurs API costs."
        }
    }
    
    var benefits: [String] {
        switch self {
        case .basic:
            return ["Fast processing", "No cost", "Simple text output"]
        case .enhanced:
            return ["Preserves structure", "Column detection", "Header formatting", "Paragraph spacing"]
        case .aiEnhanced:
            return ["Intelligent formatting", "Context-aware structure", "Advanced layout detection", "Optimal readability"]
        }
    }
}