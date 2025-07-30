//
//  DocumentLibraryViewModel.swift
//  OCRMax
//
//  Created by Sunil Pawar on 29/07/25.
//

import Foundation
import SwiftUI

@MainActor
final class DocumentLibraryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var processedDocuments: [ProcessedDocument] = []
    @Published var selectedPDFURL: URL?
    @Published var wordDocumentURL: URL?
    @Published var showingShareSheet = false
    @Published var showingCamera = false
    @Published var showingDocumentScanner = false
    @Published var capturedImages: [UIImage] = []
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Dependencies
    private let documentExporter: DocumentExporterProtocol
    
    // MARK: - Computed Properties
    var hasSelectedPDF: Bool {
        selectedPDFURL != nil
    }
    
    var selectedFileName: String {
        selectedPDFURL?.lastPathComponent ?? ""
    }
    
    var hasSelectedSource: Bool {
        hasSelectedPDF || !capturedImages.isEmpty
    }
    
    var hasDocuments: Bool {
        !processedDocuments.isEmpty
    }
    
    var recentDocuments: [ProcessedDocument] {
        return Array(processedDocuments.prefix(5))
    }
    
    // MARK: - Initialization
    init(documentExporter: DocumentExporterProtocol = DocumentExportService()) {
        self.documentExporter = documentExporter
        loadProcessedDocuments()
    }
    
    // MARK: - File Selection Methods
    func selectPDF(url: URL) {
        selectedPDFURL = url
        capturedImages = []
    }
    
    func selectImageFile(url: URL) {
        selectedPDFURL = url
        capturedImages = []
    }
    
    func clearSelection() {
        selectedPDFURL = nil
        capturedImages = []
        wordDocumentURL = nil
    }
    
    // MARK: - Camera and Scanner Methods
    func showCamera() {
        showingCamera = true
    }
    
    func showDocumentScanner() {
        showingDocumentScanner = true
    }
    
    func handleCapturedImage(_ image: UIImage) {
        capturedImages = [image]
        selectedPDFURL = nil
    }
    
    func handleScannedDocuments(_ images: [UIImage]) {
        capturedImages = images
        selectedPDFURL = nil
    }
    
    // MARK: - Document Management Methods
    func saveProcessedDocument(name: String, extractedText: String, sourceURL: URL?, wordDocumentURL: URL?) {
        guard !extractedText.isEmpty else { return }
        
        let documentName = name.isEmpty ? (sourceURL?.deletingPathExtension().lastPathComponent ?? "Scanned Document") : name
        let document = ProcessedDocument(
            name: documentName,
            extractedText: extractedText,
            createdDate: Date(),
            sourceURL: sourceURL,
            wordDocumentURL: wordDocumentURL
        )
        
        processedDocuments.append(document)
        saveDocumentsToStorage()
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
    
    func duplicateDocument(_ document: ProcessedDocument) {
        let duplicatedDocument = ProcessedDocument(
            name: "\(document.name) (Copy)",
            extractedText: document.extractedText,
            createdDate: Date(),
            sourceURL: document.sourceURL,
            wordDocumentURL: document.wordDocumentURL
        )
        
        processedDocuments.append(duplicatedDocument)
        saveDocumentsToStorage()
    }
    
    func renameDocument(_ document: ProcessedDocument, newName: String) {
        guard let index = processedDocuments.firstIndex(where: { $0.id == document.id }) else {
            return
        }
        
        let updatedDocument = ProcessedDocument(
            name: newName,
            extractedText: document.extractedText,
            createdDate: document.createdDate,
            sourceURL: document.sourceURL,
            wordDocumentURL: document.wordDocumentURL
        )
        
        processedDocuments[index] = updatedDocument
        saveDocumentsToStorage()
    }
    
    // MARK: - Export Methods
    func exportDocument(_ document: ProcessedDocument, format: DocumentFormat = .rtf) {
        Task {
            do {
                let documentURL = try documentExporter.exportDocument(from: document.extractedText, format: format)
                wordDocumentURL = documentURL
                showingShareSheet = true
            } catch {
                handleError(error)
            }
        }
    }
    
    func exportDocumentWithEnhancedFormatting(_ document: ProcessedDocument, textBlocks: [TextBlock], layoutAnalysis: LayoutAnalysis, format: DocumentFormat = .rtf) {
        Task {
            do {
                let documentURL = try documentExporter.exportDocument(
                    from: textBlocks,
                    layoutAnalysis: layoutAnalysis,
                    format: format
                )
                wordDocumentURL = documentURL
                showingShareSheet = true
            } catch {
                handleError(error)
            }
        }
    }
    
    func convertToWordDocument(extractedText: String, textBlocks: [TextBlock]? = nil, layoutAnalysis: LayoutAnalysis? = nil) {
        guard !extractedText.isEmpty else {
            showError("No text available to convert")
            return
        }
        
        Task { @MainActor in
            await exportDocument(extractedText: extractedText, textBlocks: textBlocks, layoutAnalysis: layoutAnalysis)
        }
    }
    
    // MARK: - Search and Filter Methods
    func searchDocuments(query: String) -> [ProcessedDocument] {
        guard !query.isEmpty else { return processedDocuments }
        
        return processedDocuments.filter { document in
            document.name.localizedCaseInsensitiveContains(query) ||
            document.extractedText.localizedCaseInsensitiveContains(query)
        }
    }
    
    func documentsCreatedAfter(date: Date) -> [ProcessedDocument] {
        return processedDocuments.filter { $0.createdDate >= date }
    }
    
    func documentsWithSourceURL() -> [ProcessedDocument] {
        return processedDocuments.filter { $0.sourceURL != nil }
    }
    
    func documentsWithWordExport() -> [ProcessedDocument] {
        return processedDocuments.filter { $0.wordDocumentURL != nil }
    }
    
    // MARK: - Private Methods
    
    private func saveDocumentsToStorage() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(processedDocuments) {
            UserDefaults.standard.set(encoded, forKey: "ProcessedDocuments")
        }
    }
    
    private func exportDocument(extractedText: String, textBlocks: [TextBlock]?, layoutAnalysis: LayoutAnalysis?) async {
        do {
            let documentURL: URL
            
            // Use enhanced export if we have processed text blocks with layout analysis
            if let textBlocks = textBlocks, let layoutAnalysis = layoutAnalysis {
                documentURL = try documentExporter.exportDocument(
                    from: textBlocks,
                    layoutAnalysis: layoutAnalysis,
                    format: .rtf
                )
            } else {
                // Fallback to basic export
                documentURL = try documentExporter.exportDocument(from: extractedText, format: .rtf)
            }
            
            // Set properties directly on main thread
            await MainActor.run {
                wordDocumentURL = documentURL
                showingShareSheet = true
                objectWillChange.send()
            }
            
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        if let ocrError = error as? OCRError {
            errorMessage = ocrError.localizedDescription
        } else {
            errorMessage = "Document error: \(error.localizedDescription)"
        }
        
        showingError = true
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
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

// MARK: - Document Statistics
extension DocumentLibraryViewModel {
    var totalDocuments: Int {
        processedDocuments.count
    }
    
    var totalTextLength: Int {
        processedDocuments.reduce(0) { $0 + $1.extractedText.count }
    }
    
    var averageTextLength: Int {
        guard !processedDocuments.isEmpty else { return 0 }
        return totalTextLength / processedDocuments.count
    }
    
    var documentsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return documentsCreatedAfter(date: weekAgo).count
    }
    
    var documentsThisMonth: Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return documentsCreatedAfter(date: monthAgo).count
    }
}