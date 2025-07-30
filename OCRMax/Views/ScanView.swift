//
//  ScanView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum SheetType: Identifiable {
    case camera
    case documentScanner
    case filePicker
    case shareSheet
    
    var id: String {
        switch self {
        case .camera: return "camera"
        case .documentScanner: return "documentScanner"
        case .filePicker: return "filePicker"
        case .shareSheet: return "shareSheet"
        }
    }
}

enum ScanState {
    case idle
    case capturing
    case previewing
    case processing
    case completed
    case error
}

struct ScanView: View {
    @ObservedObject var viewModel: OCRViewModel
    @State private var activeSheet: SheetType?
    @State private var scanState: ScanState = .idle
    @State private var capturedSource: CapturedSource?
    
    enum CapturedSource {
        case images([UIImage], sourceType: String)
        case file(URL, fileName: String)
        
        var displayName: String {
            switch self {
            case .images(let images, let sourceType):
                return "\(images.count) image\(images.count == 1 ? "" : "s") from \(sourceType)"
            case .file(_, let fileName):
                return fileName
            }
        }
        
        var count: Int {
            switch self {
            case .images(let images, _):
                return images.count
            case .file(_, _):
                return 1
            }
        }
    }
    
    init(viewModel: OCRViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    switch scanState {
                    case .idle:
                        idleSection
                    case .capturing:
                        capturingSection
                    case .previewing:
                        previewSection
                    case .processing:
                        processingSection
                    case .completed:
                        resultSection
                    case .error:
                        errorSection
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .camera:
                CameraView(isPresented: Binding(
                    get: { activeSheet == .camera },
                    set: { if !$0 { activeSheet = nil } }
                )) { image in
                    handleCapturedImages([image], sourceType: "Camera")
                    activeSheet = nil
                }
            case .documentScanner:
                if #available(iOS 13.0, *) {
                    DocumentScannerView(isPresented: Binding(
                        get: { activeSheet == .documentScanner },
                        set: { if !$0 { activeSheet = nil } }
                    )) { images in
                        handleCapturedImages(images, sourceType: "Scanner")
                        activeSheet = nil
                    }
                }
            case .filePicker:
                DocumentPicker { result in
                    handleFileSelection(result)
                    activeSheet = nil
                }
            case .shareSheet:
                if let wordDocumentURL = viewModel.wordDocumentURL {
                    ActivityViewController(activityItems: [wordDocumentURL])
                }
            }
        }
        .onChange(of: viewModel.showingShareSheet) { _, showing in
            if showing {
                activeSheet = .shareSheet
                viewModel.showingShareSheet = false
            }
        }
        .onChange(of: viewModel.isProcessing) { _, isProcessing in
            if !isProcessing && scanState == .processing {
                if viewModel.hasExtractedText {
                    scanState = .completed
                } else if viewModel.showingError {
                    scanState = .error
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("Try Again") { 
                scanState = .idle
                capturedSource = nil
            }
            Button("Cancel", role: .cancel) {
                scanState = .idle
                capturedSource = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - View Sections
    
    private var idleSection: some View {
        VStack(spacing: 32) {
            // Instructions Area
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
                                
                                Text("Ready to Scan")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Choose your scanning method below")
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
                }
            }
            
            // Action Buttons
            HStack(spacing: 20) {
                // Camera Button
                Button(action: {
                    scanState = .capturing
                    activeSheet = .camera
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
                        scanState = .capturing
                        activeSheet = .documentScanner
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
                    scanState = .capturing
                    activeSheet = .filePicker
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
    
    private var capturingSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Opening Scanner...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Position your document and capture")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .multilineTextAlignment(.center)
            }
            
            Button("Cancel") {
                activeSheet = nil
                scanState = .idle
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var previewSection: some View {
        VStack(spacing: 24) {
            // Preview Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                Text("Content Captured")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Preview Content
            if let source = capturedSource {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: iconForSource(source))
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready to Process")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(source.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            startProcessing()
                        }) {
                            HStack {
                                Image(systemName: "text.viewfinder")
                                Text("Extract Text")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            scanState = .idle
                            capturedSource = nil
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
        }
    }
    
    private var processingSection: some View {
        VStack(spacing: 24) {
            // Animated Processing Indicator
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
                
                Text("Extracting Text")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.progressText.isEmpty ? "Analyzing document..." : viewModel.progressText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
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
                
                Text("Document saved to library")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                        Text("Export")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(viewModel.canConvertToWord ? Color.green : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canConvertToWord)
                
                Button(action: {
                    resetToIdle()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Scan More")
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
    
    private var errorSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Processing Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.errorMessage ?? "An unknown error occurred")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    if capturedSource != nil {
                        startProcessing()
                    } else {
                        scanState = .idle
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    resetToIdle()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Scan New")
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
    
    // MARK: - Helper Methods
    
    private func handleCapturedImages(_ images: [UIImage], sourceType: String) {
        capturedSource = .images(images, sourceType: sourceType)
        scanState = .previewing
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let fileName = url.lastPathComponent
                capturedSource = .file(url, fileName: fileName)
                scanState = .previewing
            }
        case .failure(let error):
            print("Error selecting file: \(error)")
            scanState = .error
        }
    }
    
    private func startProcessing() {
        guard let source = capturedSource else { return }
        
        scanState = .processing
        
        Task {
            switch source {
            case .images(let images, _):
                viewModel.processImagesDirectly(images)
            case .file(let url, _):
                let fileExtension = url.pathExtension.lowercased()
                if fileExtension == "pdf" {
                    viewModel.processPDF(url: url)
                } else if ["jpg", "jpeg", "png"].contains(fileExtension) {
                    viewModel.processImageFile(url: url)
                }
            }
        }
    }
    
    private func resetToIdle() {
        scanState = .idle
        capturedSource = nil
        viewModel.resetState()
    }
    
    private func iconForSource(_ source: CapturedSource) -> String {
        switch source {
        case .images(_, let sourceType):
            return sourceType == "Camera" ? "camera.fill" : "doc.text.viewfinder"
        case .file(let url, _):
            let ext = url.pathExtension.lowercased()
            return ext == "pdf" ? "doc.fill" : "photo.fill"
        }
    }
    
    // Document Picker using UIViewControllerRepresentable
    struct DocumentPicker: UIViewControllerRepresentable {
        let onCompletion: (Result<[URL], Error>) -> Void
        
        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf, UTType.jpeg, UTType.png])
            picker.allowsMultipleSelection = false
            picker.delegate = context.coordinator
            return picker
        }
        
        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, UIDocumentPickerDelegate {
            let parent: DocumentPicker
            
            init(_ parent: DocumentPicker) {
                self.parent = parent
            }
            
            func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
                parent.onCompletion(.success(urls))
            }
            
            func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
                parent.onCompletion(.failure(NSError(domain: "DocumentPickerCancelled", code: 0)))
            }
        }
    }
}

#Preview {
    ScanView(viewModel: OCRViewModel())
}