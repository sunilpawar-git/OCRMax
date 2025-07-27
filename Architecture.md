# OCR Max - MVVM Architecture & SOLID Principles

## Architecture Overview

OCR Max now follows a clean MVVM (Model-View-ViewModel) architecture with SOLID principles implementation, making the codebase maintainable, testable, and extensible.

## SOLID Principles Implementation

### 1. Single Responsibility Principle (SRP)
Each class has a single, well-defined responsibility:

- **VisionOCRService**: Handles OCR using Apple's Vision framework
- **PDFProcessingService**: Manages PDF parsing and image extraction
- **DocumentExportService**: Handles document export to various formats
- **OCRViewModel**: Manages UI state and coordinates between services
- **ContentView**: Handles UI presentation only

### 2. Open/Closed Principle (OCP)
The system is open for extension but closed for modification:

- Protocol-based design allows easy addition of new OCR engines
- New document export formats can be added without modifying existing code
- New UI components can be added without changing the ViewModel

### 3. Liskov Substitution Principle (LSP)
All implementations are substitutable for their interfaces:

- Any `OCRServiceProtocol` implementation can replace another
- Different `DocumentExporterProtocol` implementations work interchangeably
- Mock implementations can substitute real services for testing

### 4. Interface Segregation Principle (ISP)
Interfaces are focused and minimal:

- `OCRServiceProtocol` only contains OCR-related methods
- `PDFProcessorProtocol` only handles PDF operations
- `DocumentExporterProtocol` only manages document export

### 5. Dependency Inversion Principle (DIP)
High-level modules don't depend on low-level modules:

- ViewModel depends on abstractions (protocols), not concrete implementations
- Services can be injected for different use cases
- Easy testing through dependency injection

## MVVM Architecture

### Model Layer
**Protocols & Services**
```
Protocols/
├── OCRServiceProtocol.swift     # OCR abstraction
├── PDFProcessorProtocol.swift   # PDF processing abstraction
└── DocumentExporterProtocol.swift # Export abstraction

Services/
├── VisionOCRService.swift       # Apple Vision OCR implementation
├── PDFProcessingService.swift   # PDF processing implementation
└── DocumentExportService.swift  # Document export implementation
```

### ViewModel Layer
**Business Logic & State Management**
```
ViewModels/
└── OCRViewModel.swift           # Main ViewModel
```

**Responsibilities:**
- Manages UI state (@Published properties)
- Coordinates between services
- Handles error states
- Provides computed properties for UI

### View Layer
**SwiftUI Views**
```
Views/
└── ContentView.swift            # Main UI
```

**Responsibilities:**
- Presents UI elements
- Binds to ViewModel properties
- Handles user interactions
- No business logic

## Key Features

### Dependency Injection
```swift
// ViewModel accepts protocol dependencies
init(ocrService: OCRServiceProtocol = VisionOCRService(),
     pdfProcessor: PDFProcessorProtocol = PDFProcessingService(),
     documentExporter: DocumentExporterProtocol = DocumentExportService())
```

### Protocol-Based Design
```swift
protocol OCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> String
    func recognizeText(from images: [UIImage], progressHandler: @escaping (String) -> Void) async throws -> String
}
```

### Error Handling
```swift
enum OCRError: LocalizedError {
    case invalidImage
    case processingFailed
    case noTextFound
    case unsupportedFormat
    case fileAccessDenied
}
```

### Reactive UI
```swift
@Published var isProcessing = false
@Published var extractedText = ""
@Published var showingError = false
```

## Testing Strategy

### Unit Tests
- **ViewModelTests**: Test business logic and state management
- **ServiceTests**: Test individual service implementations
- **MockTests**: Test with mock dependencies

### Integration Tests
- **OCRIntegrationTests**: Test complete workflows
- **End-to-End**: Test real service interactions

### Test Structure
```
OCRMaxTests/
├── Mocks/
│   ├── MockOCRService.swift
│   ├── MockPDFProcessor.swift
│   └── MockDocumentExporter.swift
├── ViewModels/
│   └── OCRViewModelTests.swift
├── Services/
│   ├── VisionOCRServiceTests.swift
│   └── DocumentExportServiceTests.swift
└── Integration/
    └── OCRIntegrationTests.swift
```

## Benefits of This Architecture

### Maintainability
- Clear separation of concerns
- Easy to locate and fix issues
- Consistent code patterns

### Testability
- Mock dependencies for unit testing
- Isolated testing of components
- High test coverage achievable

### Extensibility
- Easy to add new OCR engines
- Simple to support new export formats
- Straightforward UI modifications

### Readability
- Self-documenting code structure
- Clear naming conventions
- Logical file organization

## Future Enhancements

### Easy Extensions
1. **New OCR Engine**: Implement `OCRServiceProtocol`
2. **New Export Format**: Extend `DocumentFormat` enum
3. **Additional UI**: Create new Views that use existing ViewModel
4. **Caching**: Add caching service following same patterns

### Example: Adding Tesseract OCR
```swift
class TesseractOCRService: OCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> String {
        // Tesseract implementation
    }
}

// Inject into ViewModel
let viewModel = OCRViewModel(ocrService: TesseractOCRService())
```

This architecture ensures the codebase remains clean, testable, and maintainable while following industry best practices.