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
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var extractedText = ""
    @Published var progressText = ""
    @Published var selectedPDFURL: URL?
    @Published var wordDocumentURL: URL?
    @Published var showingShareSheet = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Dependencies
    private let ocrService: OCRServiceProtocol
    private let pdfProcessor: PDFProcessorProtocol
    private let documentExporter: DocumentExporterProtocol
    
    // MARK: - Initialization
    init(ocrService: OCRServiceProtocol = VisionOCRService(),
         pdfProcessor: PDFProcessorProtocol = PDFProcessingService(),
         documentExporter: DocumentExporterProtocol = DocumentExportService()) {
        self.ocrService = ocrService
        self.pdfProcessor = pdfProcessor
        self.documentExporter = documentExporter
    }
    
    // MARK: - Public Methods
    func processPDF(url: URL) {
        guard !isProcessing else { return }
        
        selectedPDFURL = url
        resetState()
        
        Task {
            await performOCRProcessing(url: url)
        }
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
    
    // MARK: - Private Methods
    private func resetState() {
        extractedText = ""
        progressText = ""
        wordDocumentURL = nil
        errorMessage = nil
        showingError = false
    }
    
    private func performOCRProcessing(url: URL) async {
        isProcessing = true
        progressText = "Extracting images from PDF..."
        
        do {
            let images = try pdfProcessor.extractImages(from: url)
            
            let recognizedText = try await ocrService.recognizeText(from: images) { [weak self] progress in
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
    
    var pdfFileName: String {
        selectedPDFURL?.lastPathComponent ?? ""
    }
}