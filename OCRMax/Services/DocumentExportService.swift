//
//  DocumentExportService.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation

final class DocumentExportService: DocumentExporterProtocol {
    
    private let fileManager: FileManager
    private let documentsDirectory: URL
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func exportDocument(from text: String, format: DocumentFormat) throws -> URL {
        let fileName = generateFileName(for: format)
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        let documentContent = try createDocumentContent(from: text, format: format)
        
        try documentContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    private func createDocumentContent(from text: String, format: DocumentFormat) throws -> String {
        switch format {
        case .rtf:
            return createRTFContent(from: text)
        case .docx:
            return createDocxContent(from: text)
        case .txt:
            return text
        }
    }
    
    private func createRTFContent(from text: String) -> String {
        let header = """
        {\\rtf1\\ansi\\deff0 {\\fonttbl {\\f0 Times New Roman;}}
        \\f0\\fs24
        """
        
        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\n", with: "\\par\n")
        
        let footer = "}"
        
        return header + escapedText + footer
    }
    
    private func createDocxContent(from text: String) -> String {
        let xmlHeader = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        """
        
        let paragraphs = text.components(separatedBy: .newlines)
        let xmlContent = paragraphs.compactMap { paragraph in
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            
            return """
            <w:p>
            <w:r>
            <w:t>\(trimmed.xmlEscaped)</w:t>
            </w:r>
            </w:p>
            """
        }.joined()
        
        let xmlFooter = """
        </w:body>
        </w:document>
        """
        
        return xmlHeader + xmlContent + xmlFooter
    }
    
    private func generateFileName(for format: DocumentFormat) -> String {
        let timestamp = Date().timeIntervalSince1970
        return "OCR_Extract_\(timestamp).\(format.fileExtension)"
    }
}

