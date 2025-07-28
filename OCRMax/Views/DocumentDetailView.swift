//
//  DocumentDetailView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import SwiftUI

struct DocumentDetailView: View {
    let document: ProcessedDocument
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Document Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(document.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text(document.createdDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(document.createdDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Document Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Extracted Text")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(document.extractedText.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(document.extractedText)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let wordURL = document.wordDocumentURL {
                ActivityViewController(activityItems: [wordURL, document.extractedText])
            } else {
                ActivityViewController(activityItems: [document.extractedText])
            }
        }
    }
}

#Preview {
    DocumentDetailView(document: ProcessedDocument(
        name: "Sample Document",
        extractedText: "This is a sample extracted text from a document. It contains multiple lines and paragraphs to demonstrate how the document detail view looks with longer content.",
        createdDate: Date(),
        sourceURL: nil,
        wordDocumentURL: nil
    ))
}