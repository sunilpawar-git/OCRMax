//
//  MockDocumentExporter.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
@testable import OCRMax

final class MockDocumentExporter: DocumentExporterProtocol {
    
    var shouldSucceed = true
    var mockURL = URL(fileURLWithPath: "/tmp/test.rtf")
    var mockError = OCRError.processingFailed
    var exportDocumentCallCount = 0
    var exportStructuredDocumentCallCount = 0
    var lastExportedText: String?
    var lastExportedFormat: DocumentFormat?
    var lastExportedTextBlocks: [TextBlock]?
    var lastExportedLayoutAnalysis: LayoutAnalysis?
    
    func exportDocument(from text: String, format: DocumentFormat) throws -> URL {
        exportDocumentCallCount += 1
        lastExportedText = text
        lastExportedFormat = format
        
        if shouldSucceed {
            return mockURL
        } else {
            throw mockError
        }
    }
    
    func exportDocument(from textBlocks: [TextBlock], layoutAnalysis: LayoutAnalysis, format: DocumentFormat) throws -> URL {
        exportStructuredDocumentCallCount += 1
        lastExportedTextBlocks = textBlocks
        lastExportedLayoutAnalysis = layoutAnalysis
        lastExportedFormat = format
        
        if shouldSucceed {
            return mockURL
        } else {
            throw mockError
        }
    }
    
    func reset() {
        shouldSucceed = true
        mockURL = URL(fileURLWithPath: "/tmp/test.rtf")
        mockError = OCRError.processingFailed
        exportDocumentCallCount = 0
        exportStructuredDocumentCallCount = 0
        lastExportedText = nil
        lastExportedFormat = nil
        lastExportedTextBlocks = nil
        lastExportedLayoutAnalysis = nil
    }
}