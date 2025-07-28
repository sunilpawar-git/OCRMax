//
//  LibraryView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: OCRViewModel
    
    init(viewModel: OCRViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.processedDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentListView
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadProcessedDocuments()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "folder")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
                
                Text("No Documents Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Your processed documents will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Quick Action Button
            NavigationLink(destination: ScanView(viewModel: viewModel)) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Start Scanning")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var documentListView: some View {
        List {
            ForEach(viewModel.processedDocuments) { document in
                NavigationLink(destination: DocumentDetailView(document: document)) {
                    ProcessedDocumentRowView(document: document)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .contextMenu {
                    Button(role: .destructive, action: {
                        viewModel.deleteDocument(document)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: { indexSet in
                viewModel.deleteDocuments(at: indexSet)
            })
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemGroupedBackground))
    }
    
}

struct DocumentItem: Identifiable {
    let id = UUID()
    let name: String
    let createdDate: Date
    let type: DocumentType
    let url: URL
    let thumbnailImage: String
    
    enum DocumentType: String {
        case pdf = "pdf"
        case word = "word"
        case text = "text"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.fill"
            case .word: return "doc.text.fill"
            case .text: return "text.alignleft"
            }
        }
        
        var color: Color {
            switch self {
            case .pdf: return .red
            case .word: return .blue
            case .text: return .green
            }
        }
    }
}

struct ProcessedDocumentRowView: View {
    let document: ProcessedDocument
    
    var body: some View {
        HStack(spacing: 16) {
            // Document Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 60)
                
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Document Info
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(document.createdDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(document.createdDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("OCR Document")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct DocumentRowView: View {
    let document: DocumentItem
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Document Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(document.type.color.opacity(0.1))
                    .frame(width: 50, height: 60)
                
                Image(systemName: document.type.icon)
                    .font(.title2)
                    .foregroundColor(document.type.color)
            }
            
            // Document Info
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(document.createdDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(document.type.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(document.type.color.opacity(0.1))
                    .foregroundColor(document.type.color)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Actions
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    LibraryView(viewModel: OCRViewModel())
}