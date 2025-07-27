# OCR Max - PDF to Word Converter

OCR Max is an iOS application that converts scanned PDF documents into editable Word files using advanced OCR (Optical Character Recognition) technology. The app utilizes both Apple's Vision framework and Tesseract OCR engine for accurate text recognition.

## Features

- **PDF Import**: Select PDF documents from Files app or other document providers
- **Dual OCR Engines**: Uses both Vision framework and Tesseract for optimal accuracy
- **Real-time Progress**: Shows processing progress with detailed status updates
- **Word Export**: Converts extracted text to RTF/Word-compatible format
- **Share Integration**: Built-in sharing functionality to export documents
- **Clean UI**: Modern SwiftUI interface with intuitive user experience

## Requirements

- iOS 15.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Installation

1. Clone or download this repository
2. Open `OCRMax.xcodeproj` in Xcode
3. Build and run the project on your iOS device or simulator

## Architecture

### Core Components

#### ContentView.swift
- Main user interface built with SwiftUI
- Handles PDF selection and user interactions
- Manages app state and navigation

#### OCRManager.swift
- Manages OCR processing workflow
- Integrates Vision framework for text recognition
- Handles PDF page processing and text extraction

#### PDFProcessor.swift
- Handles PDF document parsing
- Extracts images from PDF pages
- Manages PDF rendering and page counting

#### WordExporter.swift
- Converts extracted text to Word-compatible formats
- Supports RTF export for cross-platform compatibility
- Handles document formatting and structure

#### TesseractManager.swift
- Placeholder for Tesseract OCR integration
- Image preprocessing for better OCR accuracy
- Multi-language support framework

## Usage

1. **Launch the App**: Open OCR Max on your iOS device
2. **Select PDF**: Tap "Select PDF Document" to choose a scanned PDF
3. **Wait for Processing**: The app will process each page and extract text
4. **Review Results**: Preview the extracted text in the scrollable text view
5. **Export to Word**: Tap "Convert to Word Document" to create a Word file
6. **Share**: Use the share sheet to save or send the converted document

## Technical Details

### OCR Processing

The app uses a two-stage OCR approach:

1. **Vision Framework**: Apple's built-in OCR for fast, accurate text recognition
   - Optimized for on-device processing
   - Supports multiple languages
   - Advanced text detection algorithms

2. **Tesseract Integration**: Open-source OCR engine for specialized cases
   - Customizable recognition parameters
   - Support for additional languages
   - Fallback option for challenging documents

### PDF Processing

- Renders PDF pages as high-resolution images (2x scale)
- Maintains aspect ratio and image quality
- Processes pages sequentially to manage memory usage
- Supports both text-based and image-based PDFs

### Word Document Generation

- Creates RTF (Rich Text Format) documents
- Maintains text structure and formatting
- Compatible with Microsoft Word and other word processors
- Includes page breaks and paragraph formatting

## Configuration

### Info.plist Settings

The app includes necessary permissions and document type declarations:

- Document type support for PDF files
- Photo library access (for future camera integration)
- File system access for document import/export

### Build Configuration

- Minimum deployment target: iOS 15.0
- Swift language version: 5.0
- Supports both iPhone and iPad orientations

## Extending the App

### Adding Tesseract OCR

To enable full Tesseract functionality:

1. Add SwiftyTesseract dependency via Swift Package Manager
2. Download Tesseract language training data files
3. Bundle training data with the app
4. Update TesseractManager.swift with actual implementation

### Additional Features

Potential enhancements:

- Camera integration for live document scanning
- Multi-language OCR selection
- Cloud storage integration (iCloud, Google Drive, Dropbox)
- Batch processing for multiple PDFs
- Advanced image preprocessing options
- Custom output formatting options

## Troubleshooting

### Common Issues

1. **PDF Not Loading**: Ensure the PDF file is accessible and not corrupted
2. **Poor OCR Results**: Try PDFs with higher resolution or better image quality
3. **Memory Issues**: Large PDFs may require processing optimization
4. **Export Failures**: Check available storage space for output files

### Performance Tips

- Use PDFs with clear, high-contrast text
- Ensure adequate device storage for processing
- Close other apps to free up memory during processing
- Use well-lit, properly scanned source documents

## License

This project is provided as-is for educational and personal use. Please respect copyright laws when processing documents.

## Contributing

Feel free to submit issues and enhancement requests. Contributions are welcome!

## Contact

For questions or support, please create an issue in the project repository.