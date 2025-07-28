//
//  LibraryView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import SwiftUI

struct LibraryView: View {
    @State private var recentDocuments: [DocumentItem] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if recentDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentListView
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadRecentDocuments()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "doc.stack")
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
            NavigationLink(destination: ScanView()) {
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(recentDocuments) { document in
                    DocumentRowView(document: document) {
                        shareDocument(document)
                    }
                }
            }
            .padding()
        }
    }
    
    private func loadRecentDocuments() {
        // TODO: Load from Core Data or UserDefaults
        // For now, this is empty - will be populated when documents are processed
    }
    
    private func shareDocument(_ document: DocumentItem) {
        // TODO: Implement sharing functionality
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
    LibraryView()
}