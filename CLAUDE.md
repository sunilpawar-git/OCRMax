# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCR Max is an iOS application that converts scanned PDF documents into editable Word files using OCR technology. The app follows MVVM architecture with SOLID principles, utilizing Apple's Vision framework and supporting Tesseract OCR integration.

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

The codebase follows **MVVM architecture with SOLID principles**:

### Core Architecture Layers

1. **Model Layer (Protocols & Services)**
   - `Protocols/OCRServiceProtocol.swift` - OCR service abstraction
   - `Services/VisionOCRService.swift` - Apple Vision OCR implementation
   - `Services/PDFProcessingService.swift` - PDF parsing and image extraction
   - `Services/DocumentExportService.swift` - Document export (RTF, DOCX, TXT)

2. **ViewModel Layer**
   - `ViewModels/OCRViewModel.swift` - Main business logic coordinator
   - Manages UI state with `@Published` properties
   - Coordinates between services via dependency injection
   - Handles async operations and error states

3. **View Layer**
   - `ContentView.swift` - SwiftUI main interface
   - Reactive bindings to ViewModel
   - No business logic

### Key Design Patterns

**Dependency Injection**: ViewModel accepts protocol dependencies, enabling easy testing and extensibility:
```swift
init(ocrService: OCRServiceProtocol = VisionOCRService(),
     pdfProcessor: PDFProcessorProtocol = PDFProcessingService(), 
     documentExporter: DocumentExporterProtocol = DocumentExportService())
```

**Protocol-Based Design**: All services implement protocols for substitutability and testing.

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
1. PDF → Image extraction via `PDFProcessingService`
2. Images → Text recognition via `VisionOCRService`
3. Text → Document export via `DocumentExportService`
4. Progress reporting through callback handlers

### Document Export Formats
- **RTF**: Primary format for Word compatibility
- **DOCX**: XML-based Word format
- **TXT**: Plain text fallback

### Error Handling Strategy
- `OCRError` enum covers all domain-specific errors
- ViewModel centralizes error state management
- UI displays user-friendly error messages

## Extension Points

### Adding New OCR Engine
Implement `OCRServiceProtocol` and inject into ViewModel:
```swift
class TesseractOCRService: OCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> String {
        // Implementation
    }
}
```

### Adding New Export Format
1. Extend `DocumentFormat` enum
2. Add format handling in `DocumentExportService.createDocumentContent()`

### Core Data Integration
- `Persistence.swift` provides Core Data stack
- `OCRMax.xcdatamodeld` contains data model
- Currently minimal usage - prepared for future document history features

## Important Notes

- The app uses security-scoped resource access for PDF files
- Vision framework OCR works best with high-resolution, clear text images
- Export files are saved to app's Documents directory
- Async operations use Swift's structured concurrency (async/await)
- UI state management follows reactive programming patterns with Combine

## Development Guidelines

- No more than 300 lines per file

## Development Best Practices

- Write test first, then add code later