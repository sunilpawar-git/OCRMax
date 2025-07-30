//
//  OCRProcessingViewModel.swift
//  OCRMax
//
//  Created by Sunil Pawar on 29/07/25.
//

import Foundation
import SwiftUI
import PDFKit
import UIKit

@MainActor
final class OCRProcessingViewModel: ObservableObject {
    
    // MARK: - OCR Engine Types
    enum OCREngine: String, CaseIterable {
        case vision = "Apple Vision"
        case tesseract = "Tesseract OCR"
        case enhancedVision = "Enhanced Vision"
        
        var description: String {
            return self.rawValue
        }
    }
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var extractedText = ""
    @Published var progressText = ""
    @Published var selectedOCREngine: OCREngine = .vision
    @Published var selectedLanguage: String = "eng"
    @Published var availableLanguages: [String] = []
    @Published var selectedFormattingLevel: FormattingLevel = .basic
    @Published var estimatedAICost: Double = 0.0
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Internal State for Enhanced Export
    private var currentProcessedTextBlocks: [TextBlock]?
    private var currentLayoutAnalysis: LayoutAnalysis?
    
    // MARK: - Dependencies
    private let visionOCRService: OCRServiceProtocol
    private let tesseractOCRService: OCRServiceProtocol
    private let enhancedVisionOCRService: EnhancedOCRServiceProtocol
    private let pdfProcessor: PDFProcessorProtocol
    private let layoutAnalyzer: LayoutAnalyzerProtocol
    private let subscriptionManager: SubscriptionManagerProtocol
    private let aiFormattingService: AIFormattingServiceProtocol
    
    // MARK: - Computed Properties
    private var currentOCRService: OCRServiceProtocol {
        switch selectedOCREngine {
        case .vision:
            return visionOCRService
        case .tesseract:
            return tesseractOCRService
        case .enhancedVision:
            return enhancedVisionOCRService
        }
    }
    
    var canUseEnhancedFormatting: Bool {
        return subscriptionManager.canUseFeature(.enhancedLayout)
    }
    
    var canUseAIFormatting: Bool {
        return subscriptionManager.canUseFeature(.aiFormatting)
    }
    
    var hasExtractedText: Bool {
        !extractedText.isEmpty
    }
    
    var canProcess: Bool {
        !isProcessing
    }
    
    // MARK: - Initialization
    init(visionOCRService: OCRServiceProtocol = VisionOCRService(),
         tesseractOCRService: OCRServiceProtocol = TesseractOCRService(),
         enhancedVisionOCRService: EnhancedOCRServiceProtocol = EnhancedVisionOCRService(),
         pdfProcessor: PDFProcessorProtocol = PDFProcessingService(),
         layoutAnalyzer: LayoutAnalyzerProtocol = LayoutAnalyzer(),
         subscriptionManager: SubscriptionManagerProtocol = SubscriptionManager(),
         aiFormattingService: AIFormattingServiceProtocol = AIFormattingService(subscriptionManager: SubscriptionManager())) {
        self.visionOCRService = visionOCRService
        self.tesseractOCRService = tesseractOCRService
        self.enhancedVisionOCRService = enhancedVisionOCRService
        self.pdfProcessor = pdfProcessor
        self.layoutAnalyzer = layoutAnalyzer
        self.subscriptionManager = subscriptionManager
        self.aiFormattingService = aiFormattingService
        
        setupAvailableLanguages()
    }
    
    // MARK: - Public Processing Methods
    func processPDF(url: URL) {
        guard !isProcessing else { return }
        
        resetProcessingState()
        isProcessing = true
        
        Task {
            if await shouldProceedWithLargeFile(url: url) {
                await performOCRProcessing(url: url)
            } else {
                isProcessing = false
            }
        }
    }
    
    func processImages(_ images: [UIImage]) {
        print("OCRProcessing: processImages called with \(images.count) images")
        guard !isProcessing else { 
            print("OCRProcessing: Already processing, ignoring request")
            return 
        }
        
        print("OCRProcessing: Resetting state and starting processing")
        resetProcessingState()
        isProcessing = true
        
        Task { @MainActor in
            print("OCRProcessing: Starting performImageOCRProcessing")
            await performImageOCRProcessing(images: images)
        }
    }
    
    func processImageFile(url: URL) {
        guard !isProcessing else { return }
        
        resetProcessingState()
        isProcessing = true
        
        Task {
            await loadAndProcessImageFile(url: url)
        }
    }
    
    func updateFormattingLevel(_ level: FormattingLevel) {
        selectedFormattingLevel = level
        
        // Update AI cost estimation if AI formatting is selected
        if level == .aiEnhanced && !extractedText.isEmpty {
            estimatedAICost = aiFormattingService.estimatedCost(for: extractedText)
        }
    }
    
    func switchOCREngine(to engine: OCREngine) {
        selectedOCREngine = engine
        setupAvailableLanguages()
    }
    
    func setLanguage(_ language: String) {
        selectedLanguage = language
        if selectedOCREngine == .tesseract {
            tesseractOCRService.setLanguage(language)
        }
    }
    
    func resetProcessingState() {
        extractedText = ""
        progressText = ""
        errorMessage = nil
        showingError = false
        currentProcessedTextBlocks = nil
        currentLayoutAnalysis = nil
        estimatedAICost = 0.0
    }
    
    // MARK: - Enhanced Export Support
    func getProcessedTextBlocks() -> [TextBlock]? {
        return currentProcessedTextBlocks
    }
    
    func getLayoutAnalysis() -> LayoutAnalysis? {
        return currentLayoutAnalysis
    }
    
    // MARK: - Private Methods
    
    private func shouldProceedWithLargeFile(url: URL) async -> Bool {
        do {
            let fileSize = try getFileSize(url: url)
            let pageCount = pdfProcessor.getPageCount(from: url)
            
            if fileSize > 50_000_000 || pageCount > 500 {
                let sizeInMB = Double(fileSize) / 1_000_000
                progressText = "Large file detected: \(String(format: "%.1f", sizeInMB))MB, \(pageCount) pages. Processing may take several minutes and use significant memory."
                
                try await Task.sleep(nanoseconds: 3_000_000_000)
                
                if fileSize > 200_000_000 || pageCount > 2000 {
                    showError("File too large: \(String(format: "%.1f", sizeInMB))MB, \(pageCount) pages. Maximum recommended: 200MB, 2000 pages.")
                    return false
                }
            }
            
            return true
        } catch {
            showError("Unable to analyze file: \(error.localizedDescription)")
            return false
        }
    }
    
    private func getFileSize(url: URL) throws -> Int64 {
        // Try to access as security-scoped resource first, but don't fail if it's not needed
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer { 
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource() 
            }
        }
        
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
    
    func performOCRProcessing(url: URL) async {
        // isProcessing is already set to true at the start of processPDF
        progressText = "Analyzing PDF..."
        
        let pageCount = pdfProcessor.getPageCount(from: url)
        
        if pageCount > 100 {
            await performBatchOCRProcessing(url: url, pageCount: pageCount)
        } else {
            await performStandardOCRProcessing(url: url)
        }
    }
    
    private func performStandardOCRProcessing(url: URL) async {
        do {
            progressText = "Extracting images from PDF..."
            let images = try pdfProcessor.extractImages(from: url)
            
            if selectedOCREngine == .tesseract {
                tesseractOCRService.setLanguage(selectedLanguage)
            }
            
            // Enhanced processing with spatial formatting
            if selectedFormattingLevel != .basic && selectedOCREngine == .enhancedVision {
                await performEnhancedOCRProcessing(images: images)
            } else {
                // Standard processing
                let recognizedText = try await currentOCRService.recognizeText(from: images) { [weak self] progress in
                    Task { @MainActor in
                        self?.progressText = progress
                    }
                }
                
                extractedText = recognizedText
                progressText = "OCR processing completed successfully!"
            }
            
            isProcessing = false
            progressText = ""
            
        } catch {
            handleError(error)
        }
    }
    
    private func performImageOCRProcessing(images: [UIImage]) async {
        progressText = "Processing scanned images..."
        
        do {
            if selectedOCREngine == .tesseract {
                tesseractOCRService.setLanguage(selectedLanguage)
            }
            
            // Enhanced processing with spatial formatting
            if selectedFormattingLevel != .basic && selectedOCREngine == .enhancedVision {
                await performEnhancedOCRProcessing(images: images)
            } else {
                // Standard processing
                let recognizedText = try await currentOCRService.recognizeText(from: images) { [weak self] progress in
                    Task { @MainActor in
                        self?.progressText = progress
                    }
                }
                
                extractedText = recognizedText
                progressText = "OCR processing completed successfully!"
            }
            
            isProcessing = false
            progressText = ""
            
        } catch {
            handleError(error)
        }
    }
    
    private func loadAndProcessImageFile(url: URL) async {
        progressText = "Loading image file..."
        
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw OCRError.fileAccessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let imageData = try Data(contentsOf: url)
            guard let image = UIImage(data: imageData) else {
                throw OCRError.invalidImage
            }
            
            await performImageOCRProcessing(images: [image])
            
        } catch {
            handleError(error)
        }
    }
    
    private func calculateOptimalBatchSize(for pageCount: Int) -> Int {
        // Base calculation on available memory and page count
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        let estimatedMemoryPerPage: UInt64 = 10_000_000 // ~10MB per page estimate
        
        // Calculate theoretical max pages based on available memory (use 50% of total)
        let memoryBasedLimit = Int((availableMemory / 2) / estimatedMemoryPerPage)
        let memoryBasedBatchSize = max(5, min(memoryBasedLimit, 50))
        
        // Adjust based on total page count
        let countBasedBatchSize = max(10, min(pageCount / 10, 30))
        
        // Use the more conservative estimate
        let optimalBatchSize = min(memoryBasedBatchSize, countBasedBatchSize)
        
        print("OCR Batch Processing: pageCount=\(pageCount), memoryBasedSize=\(memoryBasedBatchSize), countBasedSize=\(countBasedBatchSize), optimal=\(optimalBatchSize)")
        
        return optimalBatchSize
    }
    
    private func performBatchOCRProcessing(url: URL, pageCount: Int) async {
        do {
            if selectedOCREngine == .tesseract {
                tesseractOCRService.setLanguage(selectedLanguage)
            }
            
            let batchSize = calculateOptimalBatchSize(for: pageCount)
            var allExtractedText = ""
            
            // Collect all batches first
            var allBatches: [(images: [UIImage], batchNumber: Int, totalBatches: Int)] = []
            
            try pdfProcessor.extractImagesBatch(from: url, batchSize: batchSize) { batchImages, batchNumber, totalBatchCount in
                allBatches.append((images: batchImages, batchNumber: batchNumber, totalBatches: totalBatchCount))
            }
            
            // Process each batch sequentially with async OCR
            for batch in allBatches {
                let batchProgress = Int((Double(batch.batchNumber - 1) / Double(batch.totalBatches)) * 100)
                progressText = "Processing batch \(batch.batchNumber) of \(batch.totalBatches) (\(batchProgress)% complete)"
                
                let batchText = try await currentOCRService.recognizeText(from: batch.images) { [weak self] progress in
                    Task { @MainActor in
                        self?.progressText = "Batch \(batch.batchNumber)/\(batch.totalBatches) (\(batchProgress)%): \(progress)"
                    }
                }
                
                allExtractedText += batchText
                extractedText = allExtractedText
            }
            
            progressText = "OCR processing completed successfully!"
            
            isProcessing = false
            progressText = ""
            
        } catch {
            handleError(error)
        }
    }
    
    private func performEnhancedOCRProcessing(images: [UIImage]) async {
        do {
            progressText = "Performing enhanced OCR with spatial analysis..."
            
            // Extract text blocks with spatial positioning
            let textBlocks = try await enhancedVisionOCRService.recognizeTextBlocks(from: images) { [weak self] progress in
                Task { @MainActor in
                    self?.progressText = progress
                }
            }
            
            guard !textBlocks.isEmpty else {
                throw OCRError.noTextFound
            }
            
            progressText = "Analyzing document layout..."
            
            // Analyze layout structure
            let layoutAnalysis = layoutAnalyzer.analyzeLayout(from: textBlocks)
            
            // Apply formatting based on selected level
            switch selectedFormattingLevel {
            case .basic:
                // Shouldn't reach here, but fallback to basic text
                extractedText = textBlocks.map { $0.text }.joined(separator: "\n")
                
            case .enhanced:
                // Use structured formatting
                progressText = "Applying enhanced formatting..."
                extractedText = await createEnhancedFormattedText(from: textBlocks, layoutAnalysis: layoutAnalysis)
                
            case .aiEnhanced:
                // Use AI formatting
                progressText = "Applying AI-enhanced formatting..."
                extractedText = await createAIEnhancedFormattedText(from: textBlocks, layoutAnalysis: layoutAnalysis)
            }
            
            progressText = "Enhanced OCR processing completed successfully!"
            
            // Store text blocks and layout analysis for enhanced export
            currentProcessedTextBlocks = textBlocks
            currentLayoutAnalysis = layoutAnalysis
            
            isProcessing = false
            progressText = ""
            
        } catch {
            handleError(error)
        }
    }
    
    private func createEnhancedFormattedText(from textBlocks: [TextBlock], layoutAnalysis: LayoutAnalysis) async -> String {
        // Create structured text based on layout analysis
        var formattedText = ""
        
        for textGroup in layoutAnalysis.textGroups {
            let groupText = textGroup.blocks.map { $0.text }.joined(separator: " ")
            
            switch textGroup.groupType {
            case .header:
                formattedText += "\n\n" + groupText.uppercased() + "\n"
                formattedText += String(repeating: "=", count: min(groupText.count, 50)) + "\n"
                
            case .paragraph:
                formattedText += "\n" + groupText + "\n"
                
            case .list:
                formattedText += "\n• " + groupText
                
            case .table:
                formattedText += "\n| " + groupText + " |"
                
            case .caption:
                formattedText += "\n[" + groupText + "]\n"
            }
        }
        
        return formattedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func createAIEnhancedFormattedText(from textBlocks: [TextBlock], layoutAnalysis: LayoutAnalysis) async -> String {
        do {
            // Check subscription access
            guard subscriptionManager.canUseFeature(.aiFormatting) else {
                throw OCRError.subscriptionRequired
            }
            
            let basicText = textBlocks.map { $0.text }.joined(separator: " ")
            
            // Update cost estimation
            estimatedAICost = aiFormattingService.estimatedCost(for: basicText)
            
            // Apply AI formatting
            let aiFormattedText = try await aiFormattingService.enhanceFormatting(text: basicText, layoutHints: layoutAnalysis)
            
            return aiFormattedText
            
        } catch OCRError.subscriptionRequired {
            // Fallback to enhanced formatting
            return await createEnhancedFormattedText(from: textBlocks, layoutAnalysis: layoutAnalysis)
            
        } catch {
            // Fallback to enhanced formatting on AI service error
            progressText = "AI service unavailable, using enhanced formatting..."
            return await createEnhancedFormattedText(from: textBlocks, layoutAnalysis: layoutAnalysis)
        }
    }
    
    private func setupAvailableLanguages() {
        switch selectedOCREngine {
        case .vision:
            availableLanguages = visionOCRService.getSupportedLanguages()
        case .tesseract:
            availableLanguages = tesseractOCRService.getSupportedLanguages()
        case .enhancedVision:
            availableLanguages = enhancedVisionOCRService.getSupportedLanguages()
        }
    }
    
    private func handleError(_ error: Error) {
        isProcessing = false
        progressText = ""
        
        if let ocrError = error as? OCRError {
            errorMessage = ocrError.localizedDescription
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        showingError = true
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}