//
//  ScanView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ScanView: View {
    @ObservedObject var viewModel: OCRViewModel
    @State private var isDocumentPickerPresented = false
    @State private var showingSourceActionSheet = false
    
    init(viewModel: OCRViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if viewModel.isProcessing {
                        processingSection
                    } else if viewModel.hasExtractedText {
                        resultSection
                    } else {
                        scanningSection
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.large)
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
        .confirmationDialog("Select Source", isPresented: $showingSourceActionSheet) {
            if #available(iOS 13.0, *) {
                Button("Document Scanner") {
                    viewModel.showDocumentScanner()
                }
            }
            
            Button("Camera") {
                viewModel.showCamera()
            }
            
            Button("Files") {
                isDocumentPickerPresented = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you want to add your document")
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - View Components
    private var scanningSection: some View {
        VStack(spacing: 32) {
            // Camera Preview Area
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("Position your document")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Tap to scan or choose from files")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                                    .multilineTextAlignment(.center)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                                .foregroundColor(.secondary.opacity(0.3))
                        )
                        .onTapGesture {
                            showingSourceActionSheet = true
                        }
                }
                
                // Selected file info
                selectedFileInfo
            }
            
            // Floating Action Buttons
            HStack(spacing: 20) {
                // Quick Scan Button
                Button(action: {
                    viewModel.showCamera()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                        Text("Camera")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // Document Scanner
                if #available(iOS 13.0, *) {
                    Button(action: {
                        viewModel.showDocumentScanner()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 24))
                            Text("Scanner")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.green)
                        .clipShape(Circle())
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                
                // File Import
                Button(action: {
                    isDocumentPickerPresented = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 24))
                        Text("Files")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private var selectedFileInfo: some View {
        if viewModel.hasSelectedPDF {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected File")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.selectedFileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.processPDF(url: viewModel.selectedPDFURL!)
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        } else if !viewModel.capturedImages.isEmpty {
            HStack {
                Image(systemName: "photo.stack.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Captured Images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.capturedImages.count) image(s)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Button(action: {
                    // Process captured images
                    Task {
                        await viewModel.processImages()
                    }
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private var processingSection: some View {
        VStack(spacing: 24) {
            // Animated OCR Processing
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: viewModel.isProcessing)
                    
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                Text("Processing Document")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.progressText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 20) {
            // Success Animation
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Text Extracted Successfully")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Text Preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Extracted Text Preview")
                    .font(.headline)
                
                ScrollView {
                    Text(viewModel.extractedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .frame(maxHeight: 200)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.convertToWordDocument()
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Export to Word")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(viewModel.canConvertToWord ? Color.green : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canConvertToWord)
                
                Button(action: {
                    viewModel.resetState()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Scan Again")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
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

#Preview {
    ScanView(viewModel: OCRViewModel())
}