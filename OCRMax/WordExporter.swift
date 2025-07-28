//
//  WordExporter.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import Foundation
import UIKit

class WordExporter {
    
    enum ExportError: Error {
        case creationFailed
        case writeFailed
    }
    
    func createWordDocument(from text: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "OCR_Extract_\(Date().timeIntervalSince1970).rtf"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let rtfText = createRTFDocument(from: text)
        
        do {
            try rtfText.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw ExportError.writeFailed
        }
    }
    
    private func createRTFDocument(from text: String) -> String {
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
    
    func createDocxDocument(from text: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "OCR_Extract_\(Date().timeIntervalSince1970).docx"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let docxContent = createDocxContent(from: text)
        
        do {
            try docxContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw ExportError.writeFailed
        }
    }
    
    private func createDocxContent(from text: String) -> String {
        let xmlHeader = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        """
        
        let paragraphs = text.components(separatedBy: .newlines)
        var xmlContent = ""
        
        for paragraph in paragraphs {
            if !paragraph.trimmingCharacters(in: .whitespaces).isEmpty {
                xmlContent += """
                <w:p>
                <w:r>
                <w:t>\(paragraph.xmlEscaped)</w:t>
                </w:r>
                </w:p>
                """
            }
        }
        
        let xmlFooter = """
        </w:body>
        </w:document>
        """
        
        return xmlHeader + xmlContent + xmlFooter
    }
}

