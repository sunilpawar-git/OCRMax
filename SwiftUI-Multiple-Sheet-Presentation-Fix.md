# SwiftUI Multiple Sheet Presentation Issue - Fix Reference

## Problem Statement

**Issue**: SwiftUI application crashed with the error "Currently, only presenting a single sheet is supported" when multiple sheet modifiers were attached to the same view, causing buttons to not respond or present wrong sheets.

**Symptoms Observed**:
- Camera and Scanner buttons appeared non-responsive
- Files button opened camera/scanner instead of file picker
- Camera state remained open and didn't dismiss properly
- Console errors showing sheet presentation conflicts
- App hangs and gesture timeouts

**Error Messages**:
```
Currently, only presenting a single sheet is supported.
The next sheet will be presented when the currently presented sheet gets dismissed.
Attempt to present <UIDocumentPickerViewController> on <UIHostingController> which is already presenting <PresentationHostingController>.
```

## Root Cause Analysis

SwiftUI has a fundamental limitation: **only one sheet can be presented at a time per view**. The issue occurred because multiple sheet presentation modifiers were attached to a single view:

```swift
// PROBLEMATIC CODE - Multiple sheet modifiers
.sheet(isPresented: $viewModel.showingCamera) { ... }
.sheet(isPresented: $viewModel.showingDocumentScanner) { ... }
.fileImporter(isPresented: $isDocumentPickerPresented) { ... }
.sheet(isPresented: $viewModel.showingShareSheet) { ... }
```

When multiple Boolean states could become `true` simultaneously, SwiftUI attempted to present multiple sheets, leading to conflicts and undefined behavior.

## Likely Issues Leading to This Problem

### 1. **Architecture Anti-patterns**
- Multiple `@Published` Boolean properties for sheet presentation
- Separate sheet modifiers for each modal type
- Lack of centralized presentation state management

### 2. **State Management Issues**
- Race conditions between different sheet presentation triggers
- Boolean states not being properly reset after sheet dismissal
- Complex ViewModel delegation chains causing state propagation delays

### 3. **SwiftUI API Misunderstanding**
- Treating sheet presentation like multiple simultaneous modals
- Mixing `.sheet()`, `.fileImporter()`, and other presentation modifiers
- Not understanding SwiftUI's single-sheet-per-view limitation

## Solution Implemented

### 1. **Unified Sheet Presentation System**

Created a single enum to manage all sheet types:

```swift
enum SheetType: Identifiable {
    case camera
    case documentScanner
    case filePicker
    case shareSheet
    
    var id: String {
        switch self {
        case .camera: return "camera"
        case .documentScanner: return "documentScanner"
        case .filePicker: return "filePicker"
        case .shareSheet: return "shareSheet"
        }
    }
}
```

### 2. **Single Sheet Modifier**

Replaced multiple sheet modifiers with one consolidated modifier:

```swift
@State private var activeSheet: SheetType?

.sheet(item: $activeSheet) { sheetType in
    switch sheetType {
    case .camera:
        CameraView(isPresented: .constant(true)) { image in
            viewModel.handleCapturedImage(image)
            activeSheet = nil
        }
    case .documentScanner:
        DocumentScannerView(isPresented: .constant(true)) { images in
            viewModel.handleScannedDocuments(images)
            activeSheet = nil
        }
    case .filePicker:
        DocumentPicker { result in
            handleFileSelection(result)
            activeSheet = nil
        }
    case .shareSheet:
        if let wordDocumentURL = viewModel.wordDocumentURL {
            ActivityViewController(activityItems: [wordDocumentURL])
        }
    }
}
```

### 3. **Centralized Button Actions**

Updated all button actions to use the unified system:

```swift
// Camera Button
Button(action: { activeSheet = .camera }) { ... }

// Scanner Button  
Button(action: { activeSheet = .documentScanner }) { ... }

// Files Button
Button(action: { activeSheet = .filePicker }) { ... }
```

### 4. **Custom Document Picker**

Created a UIViewControllerRepresentable wrapper to handle file selection within the unified system:

```swift
struct DocumentPicker: UIViewControllerRepresentable {
    let onCompletion: (Result<[URL], Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.pdf, UTType.jpeg, UTType.png]
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    // ... delegate implementation
}
```

## Best Practices Established

### 1. **Single Source of Truth**
- Use one `@State` variable to manage all sheet presentations
- Enum-based approach ensures only one sheet type can be active

### 2. **Proper State Management**
- Always set `activeSheet = nil` in completion handlers
- Use `onChange` modifiers to bridge between old Boolean states and new enum system

### 3. **SwiftUI Presentation Patterns**
- Prefer `.sheet(item:)` over `.sheet(isPresented:)` for multiple sheet scenarios
- Use `UIViewControllerRepresentable` for complex UIKit integrations
- Always provide proper dismissal mechanisms

## Prevention Guidelines

### 1. **Code Review Checklist**
- [ ] Only one sheet presentation modifier per view
- [ ] Sheet presentation state managed by single source
- [ ] Proper dismissal handling in all sheet completion blocks
- [ ] No mixing of `.sheet()`, `.fileImporter()`, `.fullScreenCover()` on same view

### 2. **Architecture Guidelines**
- Use enum-based state management for modal presentations
- Centralize presentation logic in parent views
- Implement proper cleanup in sheet dismissal handlers

### 3. **Testing Approach**
- Test all button combinations that could trigger sheets
- Verify sheet dismissal in all scenarios (completion, cancellation, error)
- Test rapid button tapping to catch race conditions

## Alternative Solutions

### 1. **View Composition Approach**
Split functionality across multiple child views, each with their own sheet:

```swift
VStack {
    CameraButtonView()  // Has its own .sheet() modifier
    ScannerButtonView() // Has its own .sheet() modifier  
    FilesButtonView()   // Has its own .sheet() modifier
}
```

### 2. **NavigationStack Approach**
Use NavigationStack with programmatic navigation instead of sheets for some modals.

### 3. **Custom Presentation Manager**
Create a dedicated `@ObservableObject` class to manage all presentation states.

## Related SwiftUI Limitations

1. **Single Sheet Limit**: Only one sheet per view hierarchy
2. **Modal Stacking**: Complex modal stacking requires careful state management
3. **Presentation Context**: Sheet presentation tied to specific view hierarchy levels
4. **State Timing**: Boolean state changes can cause presentation conflicts

## Files Modified

- `OCRMax/Views/ScanView.swift` - Main implementation
- Added unified sheet presentation system
- Removed multiple sheet modifiers
- Added custom DocumentPicker struct

## Verification Steps

1. **Build Success**: Project compiles without warnings
2. **Button Functionality**: All three buttons (Camera, Scanner, Files) work correctly
3. **Sheet Dismissal**: All sheets dismiss properly after completion or cancellation
4. **No Console Errors**: No more "single sheet" presentation errors
5. **State Management**: Proper state transitions between different sheet types

## Future Considerations

- Monitor iOS updates for changes to sheet presentation behavior
- Consider migrating to newer SwiftUI presentation APIs as they become available
- Evaluate performance impact of enum-based switching for complex modal scenarios
- Document any additional edge cases discovered during usage

---

**Created**: 2025-07-30  
**Last Updated**: 2025-07-30  
**SwiftUI Version**: iOS 15.0+  
**Xcode Version**: 15.0+