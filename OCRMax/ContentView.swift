//
//  ContentView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = OCRViewModel()
    @State private var isDocumentPickerPresented = false
    @State private var showingSourceActionSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                
                selectedPDFSection
                
                processingSection
                
                extractedTextSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("OCR Max")
            .navigationBarHidden(true)
        }
        .fileImporter(
            isPresented: $isDocumentPickerPresented,
            allowedContentTypes: [UTType.pdf, UTType.jpeg, UTType.png],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            shareSheet
        }
        .sheet(isPresented: $viewModel.showingCamera) {
            CameraView(isPresented: $viewModel.showingCamera) { image in
                viewModel.handleCapturedImage(image)
            }
        }
        .sheet(isPresented: $viewModel.showingDocumentScanner) {
            if #available(iOS 13.0, *) {
                DocumentScannerView(isPresented: $viewModel.showingDocumentScanner) { images in
                    viewModel.handleScannedDocuments(images)
                }
            }
        }
        .actionSheet(isPresented: $showingSourceActionSheet) {
            var buttons: [ActionSheet.Button] = []
            
            if #available(iOS 13.0, *) {
                buttons.append(.default(Text("Document Scanner")) {
                    viewModel.showDocumentScanner()
                })
            }
            
            buttons.append(.default(Text("Camera")) {
                viewModel.showCamera()
            })
            
            buttons.append(.default(Text("Files")) {
                isDocumentPickerPresented = true
            })
            
            buttons.append(.cancel())
            
            return ActionSheet(
                title: Text("Select Source"),
                message: Text("Choose how you want to add your document"),
                buttons: buttons
            )
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("OCR Max")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Convert scanned PDFs and images to editable Word documents")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var selectedPDFSection: some View {
        if viewModel.hasSelectedPDF {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected File:")
                    .font(.headline)
                Text(viewModel.selectedFileName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        } else if !viewModel.capturedImages.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Captured Images:")
                    .font(.headline)
                Text("\(viewModel.capturedImages.count) image(s) captured")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var processingSection: some View {
        Group {
            if viewModel.isProcessing {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(viewModel.progressText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                selectPDFButton
            }
        }
    }
    
    private var selectPDFButton: some View {
        Button(action: {
            showingSourceActionSheet = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Document")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private var extractedTextSection: some View {
        if viewModel.hasExtractedText {
            VStack(alignment: .leading, spacing: 10) {
                Text("Extracted Text Preview:")
                    .font(.headline)
                
                ScrollView {
                    Text(viewModel.extractedText)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 200)
                
                convertToWordButton
            }
            .padding()
        }
    }
    
    private var convertToWordButton: some View {
        Button(action: {
            viewModel.convertToWordDocument()
        }) {
            HStack {
                Image(systemName: "doc.text")
                Text("Convert to Word Document")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(viewModel.canConvertToWord ? Color.green : Color.gray)
            .cornerRadius(10)
        }
        .disabled(!viewModel.canConvertToWord)
    }
    
    @ViewBuilder
    private var shareSheet: some View {
        if let wordDocumentURL = viewModel.wordDocumentURL {
            ActivityViewController(activityItems: [wordDocumentURL])
        }
    }
    
    // MARK: - Actions
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let fileExtension = url.pathExtension.lowercased()
                
                if fileExtension == "pdf" {
                    viewModel.processPDF(url: url)
                } else if ["jpg", "jpeg", "png"].contains(fileExtension) {
                    viewModel.processImageFile(url: url)
                }
            }
        case .failure(let error):
            print("Error selecting file: \(error)")
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
