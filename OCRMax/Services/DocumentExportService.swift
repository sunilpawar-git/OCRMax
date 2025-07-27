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
        
        if text.count > 1_000_000 {
            try exportLargeDocument(text: text, to: fileURL, format: format)
        } else {
            let documentContent = try createDocumentContent(from: text, format: format)
            try documentContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        return fileURL
    }
    
    private func exportLargeDocument(text: String, to fileURL: URL, format: DocumentFormat) throws {
        let chunkSize = 100_000
        let chunks = text.chunked(into: chunkSize)
        
        switch format {
        case .rtf:
            try exportLargeRTF(chunks: chunks, to: fileURL)
        case .docx:
            try exportLargeDocx(chunks: chunks, to: fileURL)
        case .txt:
            try exportLargeTxt(chunks: chunks, to: fileURL)
        }
    }
    
    private func exportLargeRTF(chunks: [String], to fileURL: URL) throws {
        let header = """
        {\\rtf1\\ansi\\deff0 {\\fonttbl {\\f0 Times New Roman;}}
        \\f0\\fs24
        """
        
        try header.write(to: fileURL, atomically: false, encoding: .utf8)
        
        let fileHandle = try FileHandle(forWritingTo: fileURL)
        defer { fileHandle.closeFile() }
        
        fileHandle.seekToEndOfFile()
        
        for chunk in chunks {
            let escapedChunk = chunk
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "{", with: "\\{")
                .replacingOccurrences(of: "}", with: "\\}")
                .replacingOccurrences(of: "\n", with: "\\par\n")
            
            fileHandle.write(escapedChunk.data(using: .utf8)!)
        }
        
        fileHandle.write("}".data(using: .utf8)!)
    }
    
    private func exportLargeDocx(chunks: [String], to fileURL: URL) throws {
        let xmlHeader = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        """
        
        try xmlHeader.write(to: fileURL, atomically: false, encoding: .utf8)
        
        let fileHandle = try FileHandle(forWritingTo: fileURL)
        defer { fileHandle.closeFile() }
        
        fileHandle.seekToEndOfFile()
        
        for chunk in chunks {
            let paragraphs = chunk.components(separatedBy: .newlines)
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
            
            fileHandle.write(xmlContent.data(using: .utf8)!)
        }
        
        let xmlFooter = """
        </w:body>
        </w:document>
        """
        fileHandle.write(xmlFooter.data(using: .utf8)!)
    }
    
    private func exportLargeTxt(chunks: [String], to fileURL: URL) throws {
        try chunks[0].write(to: fileURL, atomically: false, encoding: .utf8)
        
        let fileHandle = try FileHandle(forWritingTo: fileURL)
        defer { fileHandle.closeFile() }
        
        fileHandle.seekToEndOfFile()
        
        for chunk in chunks.dropFirst() {
            fileHandle.write(chunk.data(using: .utf8)!)
        }
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

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}

