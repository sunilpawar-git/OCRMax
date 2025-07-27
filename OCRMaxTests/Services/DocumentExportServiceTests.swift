//
//  DocumentExportServiceTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 27/07/25.
//

import XCTest
@testable import OCRMax

final class DocumentExportServiceTests: XCTestCase {
    
    var sut: DocumentExportService!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        sut = DocumentExportService(fileManager: .default)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - RTF Export Tests
    
    func testExportDocument_RTFFormat() throws {
        let testText = "Hello World\nThis is a test document."
        
        let resultURL = try sut.exportDocument(from: testText, format: .rtf)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path), "RTF file should be created")
        XCTAssertEqual(resultURL.pathExtension, "rtf", "File should have .rtf extension")
        
        let content = try String(contentsOf: resultURL)
        XCTAssertTrue(content.contains("{\\rtf1"), "Should contain RTF header")
        XCTAssertTrue(content.contains("Hello World"), "Should contain original text")
        XCTAssertTrue(content.contains("\\par"), "Should contain RTF paragraph breaks")
    }
    
    func testExportDocument_RTFFormat_SpecialCharacters() throws {
        let testText = "Text with {braces} and \\backslashes\\"
        
        let resultURL = try sut.exportDocument(from: testText, format: .rtf)
        let content = try String(contentsOf: resultURL)
        
        XCTAssertTrue(content.contains("\\{braces\\}"), "Should escape braces")
        XCTAssertTrue(content.contains("\\\\backslashes\\\\"), "Should escape backslashes")
    }
    
    // MARK: - DOCX Export Tests
    
    func testExportDocument_DocxFormat() throws {
        let testText = "Hello World\nThis is a test document."
        
        let resultURL = try sut.exportDocument(from: testText, format: .docx)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path), "DOCX file should be created")
        XCTAssertEqual(resultURL.pathExtension, "docx", "File should have .docx extension")
        
        let content = try String(contentsOf: resultURL)
        XCTAssertTrue(content.contains("<?xml"), "Should contain XML header")
        XCTAssertTrue(content.contains("w:document"), "Should contain Word document structure")
        XCTAssertTrue(content.contains("Hello World"), "Should contain original text")
    }
    
    func testExportDocument_DocxFormat_XMLEscaping() throws {
        let testText = "Text with <tags> & \"quotes\" and 'apostrophes'"
        
        let resultURL = try sut.exportDocument(from: testText, format: .docx)
        let content = try String(contentsOf: resultURL)
        
        XCTAssertTrue(content.contains("&lt;tags&gt;"), "Should escape < and >")
        XCTAssertTrue(content.contains("&amp;"), "Should escape &")
        XCTAssertTrue(content.contains("&quot;quotes&quot;"), "Should escape quotes")
        XCTAssertTrue(content.contains("&#39;apostrophes&#39;"), "Should escape apostrophes")
    }
    
    // MARK: - TXT Export Tests
    
    func testExportDocument_TxtFormat() throws {
        let testText = "Hello World\nThis is a test document."
        
        let resultURL = try sut.exportDocument(from: testText, format: .txt)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path), "TXT file should be created")
        XCTAssertEqual(resultURL.pathExtension, "txt", "File should have .txt extension")
        
        let content = try String(contentsOf: resultURL)
        XCTAssertEqual(content, testText, "TXT content should match original text exactly")
    }
    
    // MARK: - File Name Generation Tests
    
    func testExportDocument_GeneratesUniqueFileNames() throws {
        let testText = "Test content"
        
        let url1 = try sut.exportDocument(from: testText, format: .rtf)
        let url2 = try sut.exportDocument(from: testText, format: .rtf)
        
        XCTAssertNotEqual(url1.lastPathComponent, url2.lastPathComponent, "Should generate unique file names")
        XCTAssertTrue(url1.lastPathComponent.hasPrefix("OCR_Extract_"), "Should have proper prefix")
        XCTAssertTrue(url2.lastPathComponent.hasPrefix("OCR_Extract_"), "Should have proper prefix")
    }
    
    func testExportDocument_FileNameFormat() throws {
        let testText = "Test content"
        
        let resultURL = try sut.exportDocument(from: testText, format: .rtf)
        let fileName = resultURL.lastPathComponent
        
        XCTAssertTrue(fileName.hasPrefix("OCR_Extract_"), "Should start with prefix")
        XCTAssertTrue(fileName.hasSuffix(".rtf"), "Should end with extension")
        
        // Extract timestamp part
        let timestampPart = fileName
            .replacingOccurrences(of: "OCR_Extract_", with: "")
            .replacingOccurrences(of: ".rtf", with: "")
        
        XCTAssertNotNil(Double(timestampPart), "Should contain valid timestamp")
    }
    
    // MARK: - DocumentFormat Tests
    
    func testDocumentFormat_FileExtensions() {
        XCTAssertEqual(DocumentFormat.rtf.fileExtension, "rtf")
        XCTAssertEqual(DocumentFormat.docx.fileExtension, "docx")
        XCTAssertEqual(DocumentFormat.txt.fileExtension, "txt")
    }
    
    // MARK: - Empty Content Tests
    
    func testExportDocument_EmptyText() throws {
        let emptyText = ""
        
        let resultURL = try sut.exportDocument(from: emptyText, format: .rtf)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path), "Should create file even for empty text")
        
        let content = try String(contentsOf: resultURL)
        XCTAssertTrue(content.contains("{\\rtf1"), "Should still contain RTF structure")
    }
    
    func testExportDocument_WhitespaceOnlyText() throws {
        let whitespaceText = "   \n\t  \n  "
        
        let resultURL = try sut.exportDocument(from: whitespaceText, format: .docx)
        let content = try String(contentsOf: resultURL)
        
        XCTAssertTrue(content.contains("w:document"), "Should contain document structure")
        // Should handle whitespace-only content gracefully
    }
    
    // MARK: - Large Content Tests
    
    func testExportDocument_LargeContent() throws {
        let largeText = String(repeating: "This is a line of text.\n", count: 1000)
        
        let resultURL = try sut.exportDocument(from: largeText, format: .rtf)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path), "Should handle large content")
        
        let content = try String(contentsOf: resultURL)
        XCTAssertTrue(content.count > largeText.count, "RTF content should be larger due to formatting")
    }
}