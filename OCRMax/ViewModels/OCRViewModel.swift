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
    
    // MARK: - Dependencies
    private let visionOCRService: OCRServiceProtocol
    private let tesseractOCRService: OCRServiceProtocol
    private let pdfProcessor: PDFProcessorProtocol
    private let documentExporter: DocumentExporterProtocol
    
    // MARK: - Computed Properties
    private var currentOCRService: OCRServiceProtocol {
        switch selectedOCREngine {
        case .vision:
            return visionOCRService
        case .tesseract:
            return tesseractOCRService
        }
    }
    
    // MARK: - Initialization
    init(visionOCRService: OCRServiceProtocol = VisionOCRService(),
         tesseractOCRService: OCRServiceProtocol = TesseractOCRService(),
         pdfProcessor: PDFProcessorProtocol = PDFProcessingService(),
         documentExporter: DocumentExporterProtocol = DocumentExportService()) {
        self.visionOCRService = visionOCRService
        self.tesseractOCRService = tesseractOCRService
        self.pdfProcessor = pdfProcessor
        self.documentExporter = documentExporter
        
        setupAvailableLanguages()
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
            
            let recognizedText = try await currentOCRService.recognizeText(from: images) { [weak self] progress in
                Task { @MainActor in
                    self?.progressText = progress
                }
            }
            
            extractedText = recognizedText
            progressText = "OCR processing completed successfully!"
            
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
            
            let documentURL = try documentExporter.exportDocument(from: extractedText, format: .rtf)
            
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