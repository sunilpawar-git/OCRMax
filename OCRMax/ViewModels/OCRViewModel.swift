//
//  OCRViewModel.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import SwiftUI
import PDFKit
import UIKit

@MainActor
final class OCRViewModel: ObservableObject {
    
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
    @Published var selectedPDFURL: URL?
    @Published var wordDocumentURL: URL?
    @Published var showingShareSheet = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var selectedOCREngine: OCREngine = .vision
    @Published var selectedLanguage: String = "eng"
    @Published var availableLanguages: [String] = []
    @Published var showingCamera = false
    @Published var showingDocumentScanner = false
    @Published var capturedImages: [UIImage] = []
    @Published var processedDocuments: [ProcessedDocument] = []
    @Published var selectedFormattingLevel: FormattingLevel = .basic
    @Published var showingFormattingOptions = false
    @Published var showingSubscriptionUpgrade = false
    @Published var estimatedAICost: Double = 0.0
    
    // MARK: - Internal State for Enhanced Export
    private var currentProcessedTextBlocks: [TextBlock]?
    private var currentLayoutAnalysis: LayoutAnalysis?
    
    // MARK: - Dependencies
    private let visionOCRService: OCRServiceProtocol
    private let tesseractOCRService: OCRServiceProtocol
    private let enhancedVisionOCRService: EnhancedOCRServiceProtocol
    private let pdfProcessor: PDFProcessorProtocol
    private let documentExporter: DocumentExporterProtocol
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
    
    // MARK: - Initialization
    init(visionOCRService: OCRServiceProtocol = VisionOCRService(),
         tesseractOCRService: OCRServiceProtocol = TesseractOCRService(),
         enhancedVisionOCRService: EnhancedOCRServiceProtocol = EnhancedVisionOCRService(),
         pdfProcessor: PDFProcessorProtocol = PDFProcessingService(),
         documentExporter: DocumentExporterProtocol = DocumentExportService(),
         layoutAnalyzer: LayoutAnalyzerProtocol = LayoutAnalyzer(),
         subscriptionManager: SubscriptionManagerProtocol = SubscriptionManager(),
         aiFormattingService: AIFormattingServiceProtocol = AIFormattingService(subscriptionManager: SubscriptionManager())) {
        self.visionOCRService = visionOCRService
        self.tesseractOCRService = tesseractOCRService
        self.enhancedVisionOCRService = enhancedVisionOCRService
        self.pdfProcessor = pdfProcessor
        self.documentExporter = documentExporter
        self.layoutAnalyzer = layoutAnalyzer
        self.subscriptionManager = subscriptionManager
        self.aiFormattingService = aiFormattingService
        
        setupAvailableLanguages()
        loadProcessedDocuments()
        checkSubscriptionStatus()
    }
    
    // MARK: - Subscription Management
    private func checkSubscriptionStatus() {
        Task {
            await subscriptionManager.checkSubscriptionStatus()
        }
    }
    
    func requestPremiumUpgrade(for tier: SubscriptionTier) {
        Task {
            do {
                let success = try await subscriptionManager.requestPurchase(for: tier)
                if success {
                    showingSubscriptionUpgrade = false
                    // Refresh available formatting options
                    checkSubscriptionStatus()
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    func updateFormattingLevel(_ level: FormattingLevel) {
        if level.requiresPremium && !subscriptionManager.isPremiumUser {
            showingSubscriptionUpgrade = true
            return
        }
        
        selectedFormattingLevel = level
        
        // Update AI cost estimation if AI formatting is selected
        if level == .aiEnhanced && !extractedText.isEmpty {
            estimatedAICost = aiFormattingService.estimatedCost(for: extractedText)
        }
    }
    
    // MARK: - Public Methods
    func processPDF(url: URL) {
        guard !isProcessing else { return }
        
        resetState()
        selectedPDFURL = url
        
        Task {
            if await shouldProceedWithLargeFile(url: url) {
                await performOCRProcessing(url: url)
            }
        }
    }
    
    func processImages(_ images: [UIImage]) {
        guard !isProcessing else { return }
        
        selectedPDFURL = nil
        resetState()
        
        Task {
            await performImageOCRProcessing(images: images)
        }
    }
    
    func processImageFile(url: URL) {
        guard !isProcessing else { return }
        
        resetState()
        selectedPDFURL = url
        
        Task {
            await loadAndProcessImageFile(url: url)
        }
    }
    
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
        guard url.startAccessingSecurityScopedResource() else {
            throw OCRError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
    
    func convertToWordDocument() {
        guard !extractedText.isEmpty else {
            showError("No text available to convert")
            return
        }
        
        Task {
            await exportDocument()
        }
    }
    
    func clearResults() {
        resetState()
        selectedPDFURL = nil
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
    
    func showCamera() {
        showingCamera = true
    }
    
    func showDocumentScanner() {
        showingDocumentScanner = true
    }
    
    func handleCapturedImage(_ image: UIImage) {
        capturedImages = [image]
        processImages([image])
    }
    
    func handleScannedDocuments(_ images: [UIImage]) {
        capturedImages = images
        processImages(images)
    }
    
    func processImages() async {
        processImages(capturedImages)
    }
    
    func resetState() {
        extractedText = ""
        progressText = ""
        wordDocumentURL = nil
        errorMessage = nil
        showingError = false
        capturedImages = []
        selectedPDFURL = nil
        currentProcessedTextBlocks = nil
        currentLayoutAnalysis = nil
        estimatedAICost = 0.0
    }
    
    func saveProcessedDocument() {
        guard !extractedText.isEmpty else { return }
        
        let documentName = selectedPDFURL?.deletingPathExtension().lastPathComponent ?? "Scanned Document"
        let document = ProcessedDocument(
            name: documentName,
            extractedText: extractedText,
            createdDate: Date(),
            sourceURL: selectedPDFURL,
            wordDocumentURL: wordDocumentURL
        )
        
        processedDocuments.append(document)
        
        // Save to UserDefaults for persistence
        saveDocumentsToStorage()
    }
    
    private func saveDocumentsToStorage() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(processedDocuments) {
            UserDefaults.standard.set(encoded, forKey: "ProcessedDocuments")
        }
    }
    
    func loadProcessedDocuments() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "ProcessedDocuments"),
           let documents = try? decoder.decode([ProcessedDocument].self, from: data) {
            processedDocuments = documents
        }
    }
    
    func deleteDocument(_ document: ProcessedDocument) {
        processedDocuments.removeAll { $0.id == document.id }
        saveDocumentsToStorage()
    }
    
    func deleteDocuments(at offsets: IndexSet) {
        processedDocuments.remove(atOffsets: offsets)
        saveDocumentsToStorage()
    }
    
    // MARK: - Private Methods
    
    private func performOCRProcessing(url: URL) async {
        isProcessing = true
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
            
            // Save the processed document
            saveProcessedDocument()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isProcessing = false
                self.progressText = ""
            }
            
        } catch {
            handleError(error)
        }
    }
    
    private func performImageOCRProcessing(images: [UIImage]) async {
        isProcessing = true
        progressText = "Processing scanned images..."
        
        do {
            if selectedOCREngine == .tesseract {
                tesseractOCRService.setLanguage(selectedLanguage)
            }
            
            let recognizedText = try await currentOCRService.recognizeText(from: images) { [weak self] progress in
                Task { @MainActor in
                    self?.progressText = progress
                }
            }
            
            extractedText = recognizedText
            progressText = "OCR processing completed successfully!"
            
            // Save the processed document
            saveProcessedDocument()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isProcessing = false
                self.progressText = ""
            }
            
        } catch {
            handleError(error)
        }
    }
    
    private func loadAndProcessImageFile(url: URL) async {
        isProcessing = true
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
    
    private func performBatchOCRProcessing(url: URL, pageCount: Int) async {
        var allExtractedText = ""
        let batchSize = min(20, max(10, pageCount / 50))
        
        do {
            if selectedOCREngine == .tesseract {
                tesseractOCRService.setLanguage(selectedLanguage)
            }
            
            let totalBatches = (pageCount + batchSize - 1) / batchSize
            
            for batchIndex in 0..<totalBatches {
                progressText = "Processing batch \(batchIndex + 1) of \(totalBatches)..."
                
                let startPage = batchIndex * batchSize
                let endPage = min(startPage + batchSize, pageCount)
                let batchImages = try await extractBatchImages(from: url, startPage: startPage, endPage: endPage)
                
                let batchText = try await currentOCRService.recognizeText(from: batchImages) { [weak self] progress in
                    Task { @MainActor in
                        self?.progressText = "Batch \(batchIndex + 1)/\(totalBatches): \(progress)"
                    }
                }
                
                allExtractedText += batchText
                extractedText = allExtractedText
            }
            
            progressText = "OCR processing completed successfully!"
            
            // Save the processed document
            saveProcessedDocument()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isProcessing = false
                self.progressText = ""
            }
            
        } catch {
            handleError(error)
        }
    }
    
    private func extractBatchImages(from url: URL, startPage: Int, endPage: Int) async throws -> [UIImage] {
        return try await withCheckedThrowingContinuation { continuation in
            guard url.startAccessingSecurityScopedResource() else {
                continuation.resume(throwing: OCRError.fileAccessDenied)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let pdfDocument = PDFDocument(url: url) else {
                continuation.resume(throwing: OCRError.unsupportedFormat)
                return
            }
            
            var batchImages: [UIImage] = []
            
            for pageIndex in startPage..<endPage {
                guard let page = pdfDocument.page(at: pageIndex) else {
                    continue
                }
                
                let pageImage = renderPageAsImage(page: page)
                batchImages.append(pageImage)
            }
            
            continuation.resume(returning: batchImages)
        }
    }
    
    private func renderPageAsImage(page: PDFPage) -> UIImage {
        let imageScale: CGFloat = 2.0
        let pageRect = page.bounds(for: .mediaBox)
        let scaledSize = CGSize(
            width: pageRect.width * imageScale,
            height: pageRect.height * imageScale
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        
        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.interpolationQuality = .high
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: imageScale, y: -imageScale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
    
    private func exportDocument() async {
        do {
            progressText = "Creating Word document..."
            
            let documentURL: URL
            
            // Use enhanced export if we have processed text blocks with layout analysis
            if selectedFormattingLevel != .basic,
               let storedTextBlocks = currentProcessedTextBlocks,
               let storedLayoutAnalysis = currentLayoutAnalysis {
                documentURL = try documentExporter.exportDocument(
                    from: storedTextBlocks,
                    layoutAnalysis: storedLayoutAnalysis,
                    format: .rtf
                )
            } else {
                // Fallback to basic export
                documentURL = try documentExporter.exportDocument(from: extractedText, format: .rtf)
            }
            
            wordDocumentURL = documentURL
            showingShareSheet = true
            progressText = "Document created successfully!"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.progressText = ""
            }
            
        } catch {
            handleError(error)
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
    
    // MARK: - Enhanced OCR Processing
    
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
            
            // Save the processed document
            saveProcessedDocument()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isProcessing = false
                self.progressText = ""
            }
            
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
            showingSubscriptionUpgrade = true
            return await createEnhancedFormattedText(from: textBlocks, layoutAnalysis: layoutAnalysis)
            
        } catch {
            // Fallback to enhanced formatting on AI service error
            progressText = "AI service unavailable, using enhanced formatting..."
            return await createEnhancedFormattedText(from: textBlocks, layoutAnalysis: layoutAnalysis)
        }
    }
}

// MARK: - Computed Properties
extension OCRViewModel {
    var hasSelectedPDF: Bool {
        selectedPDFURL != nil
    }
    
    var hasExtractedText: Bool {
        !extractedText.isEmpty
    }
    
    var canConvertToWord: Bool {
        hasExtractedText && !isProcessing
    }
    
    var selectedFileName: String {
        selectedPDFURL?.lastPathComponent ?? ""
    }
    
    var hasSelectedSource: Bool {
        hasSelectedPDF || !capturedImages.isEmpty
    }
}

// MARK: - ProcessedDocument Model
struct ProcessedDocument: Codable, Identifiable {
    let id: UUID = UUID()
    let name: String
    let extractedText: String
    let createdDate: Date
    let sourceURL: URL?
    let wordDocumentURL: URL?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, extractedText, createdDate, sourceURL, wordDocumentURL
    }
    
    init(name: String, extractedText: String, createdDate: Date, sourceURL: URL?, wordDocumentURL: URL?) {
        self.name = name
        self.extractedText = extractedText
        self.createdDate = createdDate
        self.sourceURL = sourceURL
        self.wordDocumentURL = wordDocumentURL
    }
}