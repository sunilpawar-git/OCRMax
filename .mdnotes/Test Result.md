load_eligibility_plist: Failed to open /Users/sunil/Library/Developer/XCTestDevices/AADB8BA9-98B7-4787-893E-62593EA3ED50/data/Containers/Data/Application/4D233490-94A2-40B9-A215-ACA768C32597/private/var/db/eligibilityd/eligibility.plist: No such file or directory(2)
No symbol named 'doc.stack' found in system symbol set
Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
Failed to send CA Event for app launch measurements for ca_event_type: 1 event_name: com.apple.app_launch_measurement.ExtendedLaunchMetrics
Test Suite 'OCRIntegrationTests' started at 2025-07-28 17:38:26.462.
Test Case '-[OCRMaxTests.OCRIntegrationTests testCompleteOCRWorkflow]' started.
fopen failed for data file: errno = 2 (No such file or directory)
Errors found! Invalidating cache...
fopen failed for data file: errno = 2 (No such file or directory)
Errors found! Invalidating cache...
Test Case '-[OCRMaxTests.OCRIntegrationTests testCompleteOCRWorkflow]' passed (3.168 seconds).
Test Case '-[OCRMaxTests.OCRIntegrationTests testDocumentExportFormats]' started.
Test Case '-[OCRMaxTests.OCRIntegrationTests testDocumentExportFormats]' passed (0.002 seconds).
Test Case '-[OCRMaxTests.OCRIntegrationTests testErrorHandling]' started.
Test Case '-[OCRMaxTests.OCRIntegrationTests testErrorHandling]' passed (0.002 seconds).
Test Case '-[OCRMaxTests.OCRIntegrationTests testMemoryUsageWithLargeContent]' started.
Test Case '-[OCRMaxTests.OCRIntegrationTests testMemoryUsageWithLargeContent]' passed (0.010 seconds).
Test Case '-[OCRMaxTests.OCRIntegrationTests testPDFToTextWorkflow]' started.
Test Case '-[OCRMaxTests.OCRIntegrationTests testPDFToTextWorkflow]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.OCRIntegrationTests testPerformanceWithMultipleImages]' started.
Test Case '-[OCRMaxTests.OCRIntegrationTests testPerformanceWithMultipleImages]' passed (5.142 seconds).
Test Case '-[OCRMaxTests.OCRIntegrationTests testViewModelIntegration]' started.
/Users/sunil/Desktop/OCRMax/OCRMaxTests/Integration/OCRIntegrationTests.swift:247: error: -[OCRMaxTests.OCRIntegrationTests testViewModelIntegration] : XCTAssertNotNil failed
/Users/sunil/Desktop/OCRMax/OCRMaxTests/Integration/OCRIntegrationTests.swift:248: error: -[OCRMaxTests.OCRIntegrationTests testViewModelIntegration] : XCTAssertEqual failed: ("nil") is not equal to ("Optional(file:///Users/sunil/Library/Developer/XCTestDevices/AADB8BA9-98B7-4787-893E-62593EA3ED50/data/Containers/Data/Application/4D233490-94A2-40B9-A215-ACA768C32597/tmp/test_58171899-4C19-4958-B7EA-2D1BA35D344B.pdf)")
Test Case '-[OCRMaxTests.OCRIntegrationTests testViewModelIntegration]' failed (5.530 seconds).
Test Suite 'OCRIntegrationTests' failed at 2025-07-28 17:38:40.318.
	 Executed 7 tests, with 2 failures (0 unexpected) in 13.855 (13.856) seconds
Test Suite 'OCRViewModelTests' started at 2025-07-28 17:38:40.323.
Test Case '-[OCRMaxTests.OCRViewModelTests testCanConvertToWord_NoTextAndNotProcessing]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testCanConvertToWord_NoTextAndNotProcessing]' passed (0.002 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testCanConvertToWord_WithTextAndNotProcessing]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testCanConvertToWord_WithTextAndNotProcessing]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testCanConvertToWord_WithTextButProcessing]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testCanConvertToWord_WithTextButProcessing]' passed (0.000 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testClearResults]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testClearResults]' passed (0.000 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testComputedProperties_InitialState]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testComputedProperties_InitialState]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testConvertToWordDocument_EmptyText]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testConvertToWordDocument_EmptyText]' passed (0.065 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testConvertToWordDocument_ExportFailure]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testConvertToWordDocument_ExportFailure]' passed (0.102 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testConvertToWordDocument_Success]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testConvertToWordDocument_Success]' passed (0.103 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testHasExtractedText_WithText]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testHasExtractedText_WithText]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testHasSelectedPDF_WithURL]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testHasSelectedPDF_WithURL]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testInitialState]' started.
Test Case '-[OCRMaxTests.OCRViewModelTests testInitialState]' passed (0.000 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_IgnoresSubsequentCallsWhileProcessing]' started.
/Users/sunil/Desktop/OCRMax/OCRMaxTests/ViewModels/OCRViewModelTests.swift:176: error: -[OCRMaxTests.OCRViewModelTests testProcessPDF_IgnoresSubsequentCallsWhileProcessing] : XCTAssertEqual failed: ("nil") is not equal to ("Optional(file:///Users/sunil/Library/Developer/XCTestDevices/AADB8BA9-98B7-4787-893E-62593EA3ED50/data/Containers/Data/Application/4D233490-94A2-40B9-A215-ACA768C32597/tmp/test_document.pdf)")
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_IgnoresSubsequentCallsWhileProcessing]' failed (0.404 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_OCRServiceFailure]' started.
/Users/sunil/Desktop/OCRMax/OCRMaxTests/ViewModels/OCRViewModelTests.swift:150: error: -[OCRMaxTests.OCRViewModelTests testProcessPDF_OCRServiceFailure] : XCTAssertEqual failed: ("nil") is not equal to ("Optional(file:///Users/sunil/Library/Developer/XCTestDevices/AADB8BA9-98B7-4787-893E-62593EA3ED50/data/Containers/Data/Application/4D233490-94A2-40B9-A215-ACA768C32597/tmp/test_document.pdf)")
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_OCRServiceFailure]' failed (0.536 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_PDFProcessorFailure]' started.
/Users/sunil/Desktop/OCRMax/OCRMaxTests/ViewModels/OCRViewModelTests.swift:127: error: -[OCRMaxTests.OCRViewModelTests testProcessPDF_PDFProcessorFailure] : XCTAssertEqual failed: ("nil") is not equal to ("Optional(file:///Users/sunil/Library/Developer/XCTestDevices/AADB8BA9-98B7-4787-893E-62593EA3ED50/data/Containers/Data/Application/4D233490-94A2-40B9-A215-ACA768C32597/tmp/test_document.pdf)")
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_PDFProcessorFailure]' failed (0.102 seconds).
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_Success]' started.
Debug - selectedPDFURL: nil
Debug - extractedText: 'Extracted PDF content'
Debug - isProcessing: false
Debug - showingError: false
Debug - errorMessage: nil
Debug - extractImagesCallCount: 1
Debug - recognizeTextFromImagesCallCount: 1
/Users/sunil/Desktop/OCRMax/OCRMaxTests/ViewModels/OCRViewModelTests.swift:107: error: -[OCRMaxTests.OCRViewModelTests testProcessPDF_Success] : XCTAssertEqual failed: ("nil") is not equal to ("Optional(file:///Users/sunil/Library/Developer/XCTestDevices/AADB8BA9-98B7-4787-893E-62593EA3ED50/data/Containers/Data/Application/4D233490-94A2-40B9-A215-ACA768C32597/tmp/test_document.pdf)")
/Users/sunil/Desktop/OCRMax/OCRMaxTests/ViewModels/OCRViewModelTests.swift:111: error: -[OCRMaxTests.OCRViewModelTests testProcessPDF_Success] : XCTAssertTrue failed
/Users/sunil/Desktop/OCRMax/OCRMaxTests/ViewModels/OCRViewModelTests.swift:113: error: -[OCRMaxTests.OCRViewModelTests testProcessPDF_Success] : XCTAssertEqual failed: ("") is not equal to ("test_document.pdf")
Test Case '-[OCRMaxTests.OCRViewModelTests testProcessPDF_Success]' failed (3.021 seconds).
Test Suite 'OCRViewModelTests' failed at 2025-07-28 17:38:44.663.
	 Executed 15 tests, with 6 failures (0 unexpected) in 4.338 (4.340) seconds
Test Suite 'VisionOCRServiceTests' started at 2025-07-28 17:38:44.668.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testCustomConfiguration]' started.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testCustomConfiguration]' passed (0.006 seconds).
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeText_HandlesVisionErrors]' started.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeText_HandlesVisionErrors]' passed (0.405 seconds).
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeText_InvalidImage]' started.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeText_InvalidImage]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeText_ValidImage]' started.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeText_ValidImage]' passed (0.644 seconds).
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeTextFromImages_EmptyArray]' started.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeTextFromImages_EmptyArray]' passed (0.005 seconds).
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeTextFromImages_ProgressReporting]' started.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeTextFromImages_ProgressReporting]' passed (0.749 seconds).
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeTextFromImages_ValidImages]' started.
Test Case '-[OCRMaxTests.VisionOCRServiceTests testRecognizeTextFromImages_ValidImages]' passed (1.101 seconds).
Test Suite 'VisionOCRServiceTests' passed at 2025-07-28 17:38:47.580.
	 Executed 7 tests, with 0 failures (0 unexpected) in 2.910 (2.912) seconds
Test Suite 'TesseractOCRServiceTests' started at 2025-07-28 17:38:47.621.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testCharacterWhitelistAndBlacklist]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testCharacterWhitelistAndBlacklist]' passed (0.004 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testEmptyImageArrayHandling]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testEmptyImageArrayHandling]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testEngineMode]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testEngineMode]' passed (0.000 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testInitialization]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testInitialization]' passed (0.002 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testInvalidImageHandling]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testInvalidImageHandling]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testLanguageSetting]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testLanguageSetting]' passed (0.000 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testLanguageSupport]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testLanguageSupport]' passed (0.000 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testPageSegmentationMode]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testPageSegmentationMode]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testRecognizeTextFromMultipleImages]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testRecognizeTextFromMultipleImages]' passed (1.006 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testRecognizeTextFromSingleImage]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testRecognizeTextFromSingleImage]' passed (0.002 seconds).
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testSupportedLanguages]' started.
Test Case '-[OCRMaxTests.TesseractOCRServiceTests testSupportedLanguages]' passed (0.001 seconds).
Test Suite 'TesseractOCRServiceTests' passed at 2025-07-28 17:38:48.640.
	 Executed 11 tests, with 0 failures (0 unexpected) in 1.018 (1.019) seconds
Test Suite 'DocumentExportServiceTests' started at 2025-07-28 17:38:48.650.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testDocumentFormat_FileExtensions]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testDocumentFormat_FileExtensions]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_DocxFormat_XMLEscaping]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_DocxFormat_XMLEscaping]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_DocxFormat]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_DocxFormat]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_EmptyText]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_EmptyText]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_FileNameFormat]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_FileNameFormat]' passed (0.008 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_GeneratesUniqueFileNames]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_GeneratesUniqueFileNames]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_LargeContent]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_LargeContent]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_RTFFormat_SpecialCharacters]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_RTFFormat_SpecialCharacters]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_RTFFormat]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_RTFFormat]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_TxtFormat]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_TxtFormat]' passed (0.001 seconds).
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_WhitespaceOnlyText]' started.
Test Case '-[OCRMaxTests.DocumentExportServiceTests testExportDocument_WhitespaceOnlyText]' passed (0.001 seconds).
Test Suite 'DocumentExportServiceTests' passed at 2025-07-28 17:38:48.668.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.017 (0.019) seconds
◇ Test run started.
↳ Testing Library Version: 124.4
↳ Target Platform: arm64-apple-ios13.0-simulator
◇ Suite OCRMaxTests started.
◇ Test example() started.
✔ Test example() passed after 0.001 seconds.
✔ Suite OCRMaxTests passed after 0.001 seconds.
✔ Test run with 1 test passed after 0.014 seconds.