//
//  OCRViewModel.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import SwiftUI

@MainActor
final class OCRViewModel: ObservableObject {
    
    // MARK: - Child ViewModels
    lazy var ocrProcessingViewModel = OCRProcessingViewModel()
    lazy var subscriptionViewModel = SubscriptionViewModel()
    lazy var documentLibraryViewModel = DocumentLibraryViewModel()
    
    // MARK: - Computed Properties from Child ViewModels
    var isProcessing: Bool {
        ocrProcessingViewModel.isProcessing
    }
    
    var extractedText: String {
        ocrProcessingViewModel.extractedText
    }
    
    var progressText: String {
        ocrProcessingViewModel.progressText
    }
    
    var selectedOCREngine: OCRProcessingViewModel.OCREngine {
        get { ocrProcessingViewModel.selectedOCREngine }
        set { ocrProcessingViewModel.selectedOCREngine = newValue }
    }
    
    var selectedLanguage: String {
        get { ocrProcessingViewModel.selectedLanguage }
        set { ocrProcessingViewModel.selectedLanguage = newValue }
    }
    
    var availableLanguages: [String] {
        ocrProcessingViewModel.availableLanguages
    }
    
    var selectedFormattingLevel: FormattingLevel {
        get { ocrProcessingViewModel.selectedFormattingLevel }
        set { ocrProcessingViewModel.selectedFormattingLevel = newValue }
    }
    
    var estimatedAICost: Double {
        ocrProcessingViewModel.estimatedAICost
    }
    
    var selectedPDFURL: URL? {
        get { documentLibraryViewModel.selectedPDFURL }
        set { documentLibraryViewModel.selectedPDFURL = newValue }
    }
    
    var wordDocumentURL: URL? {
        get { documentLibraryViewModel.wordDocumentURL }
        set { documentLibraryViewModel.wordDocumentURL = newValue }
    }
    
    var showingShareSheet: Bool {
        get { documentLibraryViewModel.showingShareSheet }
        set { documentLibraryViewModel.showingShareSheet = newValue }
    }
    
    var showingCamera: Bool {
        get { documentLibraryViewModel.showingCamera }
        set { documentLibraryViewModel.showingCamera = newValue }
    }
    
    var showingDocumentScanner: Bool {
        get { documentLibraryViewModel.showingDocumentScanner }
        set { documentLibraryViewModel.showingDocumentScanner = newValue }
    }
    
    var capturedImages: [UIImage] {
        get { documentLibraryViewModel.capturedImages }
        set { documentLibraryViewModel.capturedImages = newValue }
    }
    
    var processedDocuments: [ProcessedDocument] {
        documentLibraryViewModel.processedDocuments
    }
    
    var showingFormattingOptions: Bool {
        get { subscriptionViewModel.showingFormattingOptions }
        set { subscriptionViewModel.showingFormattingOptions = newValue }
    }
    
    var showingSubscriptionUpgrade: Bool {
        get { subscriptionViewModel.showingSubscriptionUpgrade }
        set { subscriptionViewModel.showingSubscriptionUpgrade = newValue }
    }
    
    var errorMessage: String? {
        ocrProcessingViewModel.errorMessage ?? subscriptionViewModel.errorMessage ?? documentLibraryViewModel.errorMessage
    }
    
    var showingError: Bool {
        get {
            ocrProcessingViewModel.showingError || subscriptionViewModel.showingError || documentLibraryViewModel.showingError
        }
        set {
            // SwiftUI bindings need a setter, but we handle errors in child ViewModels
            // This setter intentionally does nothing
        }
    }
    
    // MARK: - Initialization
    init() {
        // ViewModels are initialized lazily when first accessed
    }
    
    // MARK: - Public Methods
    func processPDF(url: URL) {
        documentLibraryViewModel.selectPDF(url: url)
        ocrProcessingViewModel.processPDF(url: url)
        
        // Save document after processing completes
        Task {
            // Wait for processing to complete
            while ocrProcessingViewModel.isProcessing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            if !ocrProcessingViewModel.extractedText.isEmpty {
                saveProcessedDocument()
            }
        }
    }
    
    func processImages(_ images: [UIImage]) {
        documentLibraryViewModel.handleScannedDocuments(images)
        ocrProcessingViewModel.processImages(images)
        
        // Save document after processing completes
        Task {
            // Wait for processing to complete
            while ocrProcessingViewModel.isProcessing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            if !ocrProcessingViewModel.extractedText.isEmpty {
                saveProcessedDocument()
            }
        }
    }
    
    func processImageFile(url: URL) {
        documentLibraryViewModel.selectImageFile(url: url)
        ocrProcessingViewModel.processImageFile(url: url)
        
        // Save document after processing completes
        Task {
            // Wait for processing to complete
            while ocrProcessingViewModel.isProcessing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            if !ocrProcessingViewModel.extractedText.isEmpty {
                saveProcessedDocument()
            }
        }
    }
    
    func convertToWordDocument() {
        let textBlocks = ocrProcessingViewModel.getProcessedTextBlocks()
        let layoutAnalysis = ocrProcessingViewModel.getLayoutAnalysis()
        
        documentLibraryViewModel.convertToWordDocument(
            extractedText: ocrProcessingViewModel.extractedText,
            textBlocks: textBlocks,
            layoutAnalysis: layoutAnalysis
        )
    }
    
    func clearResults() {
        ocrProcessingViewModel.resetProcessingState()
        documentLibraryViewModel.clearSelection()
    }
    
    func switchOCREngine(to engine: OCRProcessingViewModel.OCREngine) {
        ocrProcessingViewModel.switchOCREngine(to: engine)
    }
    
    func setLanguage(_ language: String) {
        ocrProcessingViewModel.setLanguage(language)
    }
    
    func showCamera() {
        documentLibraryViewModel.showCamera()
    }
    
    func showDocumentScanner() {
        documentLibraryViewModel.showDocumentScanner()
    }
    
    func handleCapturedImage(_ image: UIImage) {
        documentLibraryViewModel.handleCapturedImage(image)
    }
    
    func handleScannedDocuments(_ images: [UIImage]) {
        documentLibraryViewModel.handleScannedDocuments(images)
    }
    
    func processImagesDirectly(_ images: [UIImage]) {
        // Store images for processing but don't auto-process
        documentLibraryViewModel.capturedImages = images
        documentLibraryViewModel.selectedPDFURL = nil
        
        // Start OCR processing immediately
        Task {
            ocrProcessingViewModel.processImages(images)
            
            // Save document after processing completes
            await waitForProcessingToComplete()
            
            if !ocrProcessingViewModel.extractedText.isEmpty {
                saveProcessedDocument()
            }
        }
    }
    
    func processImages() async {
        ocrProcessingViewModel.processImages(capturedImages)
        
        // Save document after processing completes
        await waitForProcessingToComplete()
        
        if !ocrProcessingViewModel.extractedText.isEmpty {
            saveProcessedDocument()
        }
    }
    
    private func waitForProcessingToComplete() async {
        while ocrProcessingViewModel.isProcessing {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
    
    func updateFormattingLevel(_ level: FormattingLevel) {
        if !subscriptionViewModel.validateFormattingLevel(level) {
            return
        }
        
        ocrProcessingViewModel.updateFormattingLevel(level)
    }
    
    func requestPremiumUpgrade(for tier: SubscriptionTier) {
        subscriptionViewModel.requestPremiumUpgrade(for: tier)
    }
    
    private func saveProcessedDocument() {
        let documentName = documentLibraryViewModel.selectedPDFURL?.deletingPathExtension().lastPathComponent ?? "Scanned Document"
        
        documentLibraryViewModel.saveProcessedDocument(
            name: documentName,
            extractedText: ocrProcessingViewModel.extractedText,
            sourceURL: documentLibraryViewModel.selectedPDFURL,
            wordDocumentURL: documentLibraryViewModel.wordDocumentURL
        )
    }
    
    func deleteDocument(_ document: ProcessedDocument) {
        documentLibraryViewModel.deleteDocument(document)
    }
    
    func deleteDocuments(at offsets: IndexSet) {
        documentLibraryViewModel.deleteDocuments(at: offsets)
    }
    
    func loadProcessedDocuments() {
        documentLibraryViewModel.loadProcessedDocuments()
    }
    
    func resetState() {
        ocrProcessingViewModel.resetProcessingState()
        documentLibraryViewModel.clearSelection()
    }
    
}

// MARK: - Computed Properties
extension OCRViewModel {
    var hasSelectedPDF: Bool {
        documentLibraryViewModel.hasSelectedPDF
    }
    
    var hasExtractedText: Bool {
        ocrProcessingViewModel.hasExtractedText
    }
    
    var canConvertToWord: Bool {
        hasExtractedText && !isProcessing
    }
    
    var selectedFileName: String {
        documentLibraryViewModel.selectedFileName
    }
    
    var hasSelectedSource: Bool {
        documentLibraryViewModel.hasSelectedSource
    }
    
    var canUseEnhancedFormatting: Bool {
        subscriptionViewModel.canUseEnhancedFormatting
    }
    
    var canUseAIFormatting: Bool {
        subscriptionViewModel.canUseAIFormatting
    }
    
    var isPremiumUser: Bool {
        subscriptionViewModel.isPremiumUser
    }
    
    var currentTier: SubscriptionTier {
        subscriptionViewModel.currentTier
    }
}