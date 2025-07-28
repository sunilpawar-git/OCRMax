# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCR Max is an iOS application that converts scanned PDF documents into editable Word files using OCR technology. The app follows MVVM architecture with SOLID principles, utilizing Apple's Vision framework and supporting Tesseract OCR integration. The app supports processing large PDFs (up to 2000 pages, 200MB) through intelligent batch processing and memory management.

## Build Commands

### Building the Project
```bash
# Clean and build for iOS Simulator
xcodebuild -project OCRMax.xcodeproj -scheme OCRMax -destination 'platform=iOS Simulator,name=iPhone 16' clean build

# Build for device (requires signing)
xcodebuild -project OCRMax.xcodeproj -scheme OCRMax -destination 'platform=iOS,name=<device-name>' build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project OCRMax.xcodeproj -scheme OCRMax -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test class
xcodebuild test -project OCRMax.xcodeproj -scheme OCRMax -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OCRMaxTests/OCRViewModelTests

# Run single test method
xcodebuild test -project OCRMax.xcodeproj -scheme OCRMax -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OCRMaxTests/OCRViewModelTests/testProcessPDF_Success
```

### Project Requirements
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Architecture Overview

The codebase follows **MVVM architecture with SOLID principles** and implements a comprehensive OCR formatting enhancement system with subscription-based premium features:

### Core Architecture Layers

1. **Model Layer (Protocols & Services)**
   - `Protocols/OCRServiceProtocol.swift` - OCR service abstraction with enhanced spatial capabilities
   - `Models/TextBlock.swift` - Positioned text data structure for spatial analysis
   - `Services/VisionOCRService.swift` - Apple Vision OCR implementation  
   - `Services/EnhancedVisionOCRService.swift` - Vision OCR with bounding box extraction
   - `Services/PDFProcessingService.swift` - PDF parsing and image extraction
   - `Services/DocumentExportService.swift` - Document export with spatial formatting (RTF, DOCX, TXT)
   - `Services/LayoutAnalyzer.swift` - Intelligent document structure analysis
   - `Services/SubscriptionManager.swift` - StoreKit integration for premium features
   - `Services/AIFormattingService.swift` - OpenAI API integration for AI-enhanced formatting

2. **ViewModel Layer**
   - `ViewModels/OCRViewModel.swift` - Main business logic coordinator with premium feature integration
   - `ViewModels/FormattingOptionsViewModel.swift` - Premium UI management for formatting selection
   - Manages UI state with `@Published` properties
   - Coordinates between services via dependency injection
   - Handles async operations and error states

3. **View Layer**
   - `ContentView.swift` - SwiftUI main interface with premium feature access
   - `Views/` - Additional UI components (LibraryView, SettingsView, etc.)
   - Reactive bindings to ViewModels
   - No business logic

### Key Design Patterns

**Dependency Injection**: ViewModels accept protocol dependencies, enabling easy testing and extensibility:
```swift
init(visionOCRService: OCRServiceProtocol = VisionOCRService(),
     enhancedVisionOCRService: EnhancedOCRServiceProtocol = EnhancedVisionOCRService(),
     layoutAnalyzer: LayoutAnalyzerProtocol = LayoutAnalyzer(),
     subscriptionManager: SubscriptionManagerProtocol = SubscriptionManager(),
     aiFormattingService: AIFormattingServiceProtocol = AIFormattingService())
```

**Protocol-Based Design**: All services implement protocols for substitutability and testing.

**Premium Feature Architecture**: Three-tier subscription model (Free, Pro $4.99, Pro+ $9.99) with feature gating:
- **Free**: Basic OCR text extraction
- **Pro**: Enhanced layout preservation with spatial analysis  
- **Pro+**: AI-powered intelligent formatting via OpenAI API

**Spatial Text Analysis**: `TextBlock` model captures positioning data from Apple Vision for intelligent document structure detection.

**Batch Processing**: Large PDFs (>100 pages) automatically use memory-efficient batch processing to prevent iOS memory termination.

**Error Handling**: Centralized error types in `OCRError` enum with localized descriptions.

## Testing Strategy

### Test Structure
- `OCRMaxTests/Mocks/` - Mock implementations for dependency injection
- `OCRMaxTests/ViewModels/` - Unit tests for business logic
- `OCRMaxTests/Services/` - Unit tests for service implementations  
- `OCRMaxTests/Integration/` - End-to-end workflow tests

### Testing Approach
- Mock dependencies are injected into ViewModels for isolated testing
- Async operations tested with proper expectation handling
- Error scenarios validated through mock failure states

## Legacy Components

The following files exist for backward compatibility but are superseded by the new architecture:
- `OCRManager.swift` - Replaced by `VisionOCRService.swift`
- `PDFProcessor.swift` - Replaced by `PDFProcessingService.swift`
- `WordExporter.swift` - Replaced by `DocumentExportService.swift`
- `TesseractManager.swift` - Placeholder for future Tesseract integration

## Key Implementation Details

### OCR Processing Flow
1. **File Validation**: Check file size and page count with user warnings for large files
2. **Processing Mode Selection**: Automatic choice between standard (<100 pages) and batch processing (>100 pages)
3. **Formatting Level Selection**: User chooses between Basic (free), Enhanced (Pro), or AI-Enhanced (Pro+)
4. **PDF → Image Extraction**: Via `PDFProcessingService` with memory-efficient batch loading
5. **Images → Text Recognition**: 
   - Basic: Via `VisionOCRService` or `TesseractOCRService`
   - Enhanced/AI: Via `EnhancedVisionOCRService` with spatial positioning
6. **Layout Analysis**: Via `LayoutAnalyzer` for enhanced/AI formatting (columns, headers, spacing)
7. **AI Enhancement**: Via `AIFormattingService` for Pro+ users with cost estimation
8. **Text → Document Export**: Via `DocumentExportService` with spatial formatting preservation
9. **Progress Reporting**: Real-time updates through callback handlers

### Large PDF Support
- **Batch Size**: Adaptive (10-50 pages) based on total document size
- **Memory Management**: Images released after each batch to prevent crashes
- **File Limits**: Warns at 50MB/500 pages, blocks at 200MB/2000 pages
- **Progress Tracking**: Per-batch progress updates with estimated completion

### Document Export Formats
- **RTF**: Primary format for Word compatibility with streaming export for large files
- **DOCX**: XML-based Word format with chunked processing
- **TXT**: Plain text fallback with efficient memory usage
- **Spatial Formatting**: Enhanced exports preserve document structure (headers, columns, spacing) via `LayoutAnalysis`

### Error Handling Strategy
- `OCRError` enum covers all domain-specific errors
- ViewModel centralizes error state management
- UI displays user-friendly error messages

### Premium Feature Integration
- **Subscription Tiers**: Defined in `SubscriptionTier` enum with StoreKit integration
- **Feature Gating**: `SubscriptionManager.canUseFeature(_:)` controls access to premium functionality
- **Cost Estimation**: AI formatting includes cost estimation and user warnings via `AIFormattingService.estimatedCost(for:)`

## Extension Points

### Adding New OCR Engine
Implement `OCRServiceProtocol` or `EnhancedOCRServiceProtocol` and add to ViewModel's OCREngine enum:
```swift
class CustomOCRService: EnhancedOCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> String {
        // Basic OCR implementation
    }
    
    func recognizeTextBlocks(from image: UIImage) async throws -> [TextBlock] {
        // Enhanced OCR with spatial positioning
    }
}
```

### Adding New Export Format
1. Extend `DocumentFormat` enum in `OCRServiceProtocol.swift`
2. Add format handling in `DocumentExportService.createDocumentContent()`
3. Add spatial formatting support in `createStructuredDocumentContent()`
4. Add streaming export case in `exportLargeDocument()` for large files

### Adding New Premium Feature
1. Add to `PremiumFeature` enum in `OCRServiceProtocol.swift`
2. Update `SubscriptionManager.canUseFeature(_:)` logic
3. Add feature gating in relevant ViewModels

### Core Data Integration
- `Persistence.swift` provides Core Data stack
- `OCRMax.xcdatamodeld` contains data model
- Currently minimal usage - prepared for future document history features

## Critical Implementation Details

### Memory Management for Large Files
- **Batch Processing**: PDFs >100 pages automatically use `performBatchOCRProcessing()`
- **Image Disposal**: Each batch of images is processed and immediately released
- **Streaming Export**: Files >1M characters use `FileHandle` for chunked writing
- **Progress Updates**: Real-time UI updates prevent blocking during long operations

### Security-Scoped Resources
- All PDF access uses `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`
- Properly wrapped in defer blocks to ensure cleanup

### Async/Await Architecture
- All OCR operations use structured concurrency
- `@MainActor` ensures UI updates on main thread
- Progress callbacks use `Task { @MainActor in }` for thread safety

## Development Guidelines

- **300-Line Rule**: No more than 300 lines per file for maintainability
- **Test-Driven Development**: Write tests first, then implement functionality  
- **Mock-Based Testing**: Use `OCRMaxTests/Mocks/` for dependency injection in tests
- **MainActor Usage**: ViewModels are `@MainActor` - ensure tests handle this properly
- **Protocol Conformance**: Update mock implementations when adding protocol methods
- **Premium Feature Testing**: Test both free and premium user scenarios
- **Large File Testing**: Always test large file scenarios when modifying PDF processing
- **Memory Management**: Use batch processing patterns for operations that scale with document size
- **Security-Scoped Resources**: Properly wrap PDF access with `startAccessingSecurityScopedResource()`