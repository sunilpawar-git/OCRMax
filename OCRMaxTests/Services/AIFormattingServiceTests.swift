//
//  AIFormattingServiceTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 28/07/25.
//

import XCTest
@testable import OCRMax

final class AIFormattingServiceTests: XCTestCase {
    
    var aiFormattingService: AIFormattingService!
    var mockAPIClient: MockAIAPIClient!
    var mockSubscriptionManager: MockSubscriptionManager!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAIAPIClient()
        mockSubscriptionManager = MockSubscriptionManager()
        aiFormattingService = AIFormattingService(
            apiClient: mockAPIClient,
            subscriptionManager: mockSubscriptionManager
        )
    }
    
    override func tearDown() {
        aiFormattingService = nil
        mockAPIClient = nil
        mockSubscriptionManager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testBasicTextFormatting() async throws {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.mockResponse = "Properly formatted text with correct paragraphs and spacing."
        
        let inputText = "poorly formatted text without proper spacing"
        let layoutHints = createBasicLayoutAnalysis()
        
        let result = try await aiFormattingService.enhanceFormatting(text: inputText, layoutHints: layoutHints)
        
        XCTAssertTrue(mockAPIClient.requestSent)
        XCTAssertTrue(result.contains("formatted"))
        XCTAssertEqual(mockAPIClient.lastRequestText, inputText)
    }
    
    func testComplexDocumentFormatting() async throws {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.mockResponse = """
        # Document Title
        
        This is the first paragraph with proper formatting and structure.
        
        This is the second paragraph that continues the document flow.
        
        ## Section Header
        
        - List item 1
        - List item 2
        - List item 3
        """
        
        let inputText = "DOCUMENT TITLE first paragraph second paragraph SECTION HEADER list item 1 list item 2 list item 3"
        let layoutHints = createComplexLayoutAnalysis()
        
        let result = try await aiFormattingService.enhanceFormatting(text: inputText, layoutHints: layoutHints)
        
        XCTAssertTrue(result.contains("# Document Title"))
        XCTAssertTrue(result.contains("## Section Header"))
        XCTAssertTrue(result.contains("- List item"))
    }
    
    // MARK: - Subscription Gate Tests
    
    func testFreeUserBlocked() async {
        mockSubscriptionManager.mockCurrentTier = .free
        
        let inputText = "test text"
        let layoutHints = createBasicLayoutAnalysis()
        
        do {
            _ = try await aiFormattingService.enhanceFormatting(text: inputText, layoutHints: layoutHints)
            XCTFail("Should have thrown subscription required error")
        } catch OCRError.subscriptionRequired {
            // Expected behavior
            XCTAssertFalse(mockAPIClient.requestSent)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testPremiumUserAccess() async throws {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.mockResponse = "formatted text"
        
        let result = try await aiFormattingService.enhanceFormatting(
            text: "test", 
            layoutHints: createBasicLayoutAnalysis()
        )
        
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(mockAPIClient.requestSent)
    }
    
    // MARK: - Error Handling Tests
    
    func testAPIServiceUnavailable() async {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.shouldFailRequest = true
        mockAPIClient.mockError = URLError(.notConnectedToInternet)
        
        do {
            _ = try await aiFormattingService.enhanceFormatting(
                text: "test", 
                layoutHints: createBasicLayoutAnalysis()
            )
            XCTFail("Should have thrown service unavailable error")
        } catch OCRError.aiServiceUnavailable {
            // Expected behavior
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testAPIRateLimitHandling() async {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.shouldFailRequest = true
        mockAPIClient.mockError = APIError.rateLimited
        
        do {
            _ = try await aiFormattingService.enhanceFormatting(
                text: "test", 
                layoutHints: createBasicLayoutAnalysis()
            )
            XCTFail("Should have thrown service unavailable error")
        } catch OCRError.aiServiceUnavailable {
            // Expected behavior
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testEmptyResponseHandling() async {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.isOnline = true
        mockAPIClient.mockResponse = ""
        
        do {
            _ = try await aiFormattingService.enhanceFormatting(
                text: "test", 
                layoutHints: createBasicLayoutAnalysis()
            )
            XCTFail("Should have thrown processing failed error")
        } catch OCRError.processingFailed {
            // Expected behavior - empty response should trigger processing failed
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Cost Estimation Tests
    
    func testCostEstimationShortText() {
        let shortText = "This is a short text"
        let cost = aiFormattingService.estimatedCost(for: shortText)
        
        XCTAssertGreaterThan(cost, 0)
        XCTAssertLessThan(cost, 0.10) // Should be very cheap for short text
    }
    
    func testCostEstimationLongText() {
        let longText = String(repeating: "This is a long text. ", count: 1000)
        let cost = aiFormattingService.estimatedCost(for: longText)
        
        XCTAssertGreaterThan(cost, 0.10)
        XCTAssertLessThan(cost, 2.00) // Reasonable upper bound
    }
    
    func testCostEstimationEmptyText() {
        let cost = aiFormattingService.estimatedCost(for: "")
        XCTAssertEqual(cost, 0.0)
    }
    
    // MARK: - Service Availability Tests
    
    func testServiceAvailableWhenOnline() {
        mockAPIClient.isOnline = true
        XCTAssertTrue(aiFormattingService.isAvailable())
    }
    
    func testServiceUnavailableWhenOffline() {
        mockAPIClient.isOnline = false
        XCTAssertFalse(aiFormattingService.isAvailable())
    }
    
    // MARK: - Layout Hints Integration Tests
    
    func testHeaderDetectionIntegration() async throws {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.mockResponse = "# Formatted Header\n\nBody text follows."
        
        let layoutHints = createLayoutWithHeaders()
        
        let result = try await aiFormattingService.enhanceFormatting(
            text: "HEADER body text", 
            layoutHints: layoutHints
        )
        
        XCTAssertTrue(result.contains("# Formatted Header"))
        XCTAssertTrue(mockAPIClient.lastLayoutHints?.textGroups.contains { $0.groupType == .header } ?? false)
    }
    
    func testColumnLayoutIntegration() async throws {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.mockResponse = "Column 1 text | Column 2 text"
        
        let layoutHints = createLayoutWithColumns()
        
        let result = try await aiFormattingService.enhanceFormatting(
            text: "column 1 text column 2 text", 
            layoutHints: layoutHints
        )
        
        XCTAssertTrue(result.contains("|"))
        XCTAssertEqual(mockAPIClient.lastLayoutHints?.columns.count, 2)
    }
    
    // MARK: - Performance Tests
    
    func testLargeTextHandling() async throws {
        mockSubscriptionManager.mockCurrentTier = .premium
        mockAPIClient.mockResponse = "Formatted large document"
        
        let largeText = String(repeating: "This is a sentence. ", count: 5000)
        let layoutHints = createBasicLayoutAnalysis()
        
        let startTime = Date()
        let result = try await aiFormattingService.enhanceFormatting(text: largeText, layoutHints: layoutHints)
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(result.isEmpty)
        XCTAssertLessThan(duration, 30.0) // Should complete within 30 seconds
    }
    
    // MARK: - Helper Methods
    
    private func createBasicLayoutAnalysis() -> LayoutAnalysis {
        let textBlock = TextBlock(
            text: "Sample text",
            boundingBox: CGRect(x: 50, y: 50, width: 200, height: 20),
            confidence: 0.9
        )
        
        let column = ColumnGroup(
            textBlocks: [textBlock],
            boundingBox: CGRect(x: 50, y: 50, width: 200, height: 20),
            columnIndex: 0
        )
        
        let spacing = SpacingInfo(
            averageLineSpacing: 15.0,
            averageWordSpacing: 5.0,
            paragraphSpacing: 20.0
        )
        
        let textGroup = TextGroup(
            blocks: [textBlock],
            groupType: .paragraph,
            confidence: 0.85
        )
        
        return LayoutAnalysis(
            columns: [column],
            spacing: spacing,
            textGroups: [textGroup],
            suggestedIndentation: []
        )
    }
    
    private func createComplexLayoutAnalysis() -> LayoutAnalysis {
        let headerBlock = TextBlock(
            text: "DOCUMENT TITLE",
            boundingBox: CGRect(x: 100, y: 50, width: 200, height: 30),
            confidence: 0.95
        )
        
        let bodyBlock = TextBlock(
            text: "Body text",
            boundingBox: CGRect(x: 50, y: 100, width: 300, height: 20),
            confidence: 0.9
        )
        
        let headerGroup = TextGroup(blocks: [headerBlock], groupType: .header, confidence: 0.95)
        let bodyGroup = TextGroup(blocks: [bodyBlock], groupType: .paragraph, confidence: 0.9)
        
        return LayoutAnalysis(
            columns: [],
            spacing: SpacingInfo(averageLineSpacing: 20, averageWordSpacing: 6, paragraphSpacing: 25),
            textGroups: [headerGroup, bodyGroup],
            suggestedIndentation: []
        )
    }
    
    private func createLayoutWithHeaders() -> LayoutAnalysis {
        let headerBlock = TextBlock(
            text: "HEADER",
            boundingBox: CGRect(x: 50, y: 50, width: 100, height: 30),
            confidence: 0.95
        )
        
        let headerGroup = TextGroup(blocks: [headerBlock], groupType: .header, confidence: 0.95)
        
        return LayoutAnalysis(
            columns: [],
            spacing: SpacingInfo(averageLineSpacing: 20, averageWordSpacing: 5, paragraphSpacing: 25),
            textGroups: [headerGroup],
            suggestedIndentation: []
        )
    }
    
    private func createLayoutWithColumns() -> LayoutAnalysis {
        let leftBlock = TextBlock(
            text: "Left column",
            boundingBox: CGRect(x: 50, y: 50, width: 150, height: 20),
            confidence: 0.9
        )
        
        let rightBlock = TextBlock(
            text: "Right column",
            boundingBox: CGRect(x: 250, y: 50, width: 150, height: 20),
            confidence: 0.9
        )
        
        let leftColumn = ColumnGroup(textBlocks: [leftBlock], boundingBox: leftBlock.boundingBox, columnIndex: 0)
        let rightColumn = ColumnGroup(textBlocks: [rightBlock], boundingBox: rightBlock.boundingBox, columnIndex: 1)
        
        return LayoutAnalysis(
            columns: [leftColumn, rightColumn],
            spacing: SpacingInfo(averageLineSpacing: 15, averageWordSpacing: 5, paragraphSpacing: 20),
            textGroups: [],
            suggestedIndentation: []
        )
    }
}