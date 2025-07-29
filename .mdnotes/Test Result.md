load_eligibility_plist: Failed to open /Users/sunil/Library/Developer/XCTestDevices/591EBF0D-5E7F-42D9-9836-F839621279B3/data/Containers/Data/Application/0E777CB3-AA5C-4BD4-9FE7-9ED1663AF813/private/var/db/eligibilityd/eligibility.plist: No such file or directory(2)
Test Suite 'BatchProcessingIntegrationTests' started at 2025-07-29 18:11:04.796.
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingErrorHandling]' started.
/Users/sunil/Desktop/OCRMax/OCRMaxTests/Integration/BatchProcessingIntegrationTests.swift:222: error: -[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingErrorHandling] : XCTAssertTrue failed
/Users/sunil/Desktop/OCRMax/OCRMaxTests/Integration/BatchProcessingIntegrationTests.swift:223: error: -[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingErrorHandling] : XCTAssertNotNil failed
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingErrorHandling]' failed (0.357 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingMemoryEfficiency]' started.
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
OCRProcessingViewModel: Got page count: 150
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 150 pages
OCR Batch Processing: pageCount=150, memoryBasedSize=50, countBasedSize=15, optimal=15
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 15
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/10
OCRProcessingViewModel: Batch callback called - batch 2/10
OCRProcessingViewModel: Batch callback called - batch 3/10
OCRProcessingViewModel: Batch callback called - batch 4/10
OCRProcessingViewModel: Batch callback called - batch 5/10
OCRProcessingViewModel: Batch callback called - batch 6/10
OCRProcessingViewModel: Batch callback called - batch 7/10
OCRProcessingViewModel: Batch callback called - batch 8/10
OCRProcessingViewModel: Batch callback called - batch 9/10
OCRProcessingViewModel: Batch callback called - batch 10/10
OCRProcessingViewModel: extractImagesBatch completed, collected 10 batches
/Users/sunil/Desktop/OCRMax/OCRMaxTests/Integration/BatchProcessingIntegrationTests.swift:200: error: -[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingMemoryEfficiency] : XCTAssertEqual failed: ("0") is not equal to ("1")
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingMemoryEfficiency]' failed (0.023 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingPerformance]' started.
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=200
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=200
OCRProcessingViewModel: Got page count: 200
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 200 pages
OCR Batch Processing: pageCount=200, memoryBasedSize=50, countBasedSize=20, optimal=20
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 20
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/10
OCRProcessingViewModel: Batch callback called - batch 2/10
OCRProcessingViewModel: Batch callback called - batch 3/10
OCRProcessingViewModel: Batch callback called - batch 4/10
OCRProcessingViewModel: Batch callback called - batch 5/10
OCRProcessingViewModel: Batch callback called - batch 6/10
OCRProcessingViewModel: Batch callback called - batch 7/10
OCRProcessingViewModel: Batch callback called - batch 8/10
OCRProcessingViewModel: Batch callback called - batch 9/10
OCRProcessingViewModel: Batch callback called - batch 10/10
OCRProcessingViewModel: extractImagesBatch completed, collected 10 batches
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingPerformance]' passed (0.006 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingProgressReporting]' started.
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=100
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=100
OCRProcessingViewModel: Got page count: 100
OCRProcessingViewModel: Using standard processing (pageCount <= 100)
OCRProcessingViewModel: Starting standard processing
OCRProcessingViewModel: About to call pdfProcessor.extractImages
MockPDFProcessor.extractImages called, count now: 1, instance: ObjectIdentifier(0x000060000296a370)
OCRProcessingViewModel: extractImages returned 100 images
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
OCRProcessingViewModel: Got page count: 150
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 150 pages
OCR Batch Processing: pageCount=150, memoryBasedSize=50, countBasedSize=15, optimal=15
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 15
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/10
OCRProcessingViewModel: Batch callback called - batch 2/10
OCRProcessingViewModel: Batch callback called - batch 3/10
OCRProcessingViewModel: Batch callback called - batch 4/10
OCRProcessingViewModel: Batch callback called - batch 5/10
OCRProcessingViewModel: Batch callback called - batch 6/10
OCRProcessingViewModel: Batch callback called - batch 7/10
OCRProcessingViewModel: Batch callback called - batch 8/10
OCRProcessingViewModel: Batch callback called - batch 9/10
OCRProcessingViewModel: Batch callback called - batch 10/10
OCRProcessingViewModel: extractImagesBatch completed, collected 10 batches
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingProgressReporting]' passed (3.676 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingResultsAvailableForExport]' started.
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingResultsAvailableForExport]' passed (0.008 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingWithEnhancedFormatting]' started.
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
OCRProcessingViewModel: Got page count: 150
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 150 pages
OCR Batch Processing: pageCount=150, memoryBasedSize=50, countBasedSize=15, optimal=15
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 15
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/10
OCRProcessingViewModel: Batch callback called - batch 2/10
OCRProcessingViewModel: Batch callback called - batch 3/10
OCRProcessingViewModel: Batch callback called - batch 4/10
OCRProcessingViewModel: Batch callback called - batch 5/10
OCRProcessingViewModel: Batch callback called - batch 6/10
OCRProcessingViewModel: Batch callback called - batch 7/10
OCRProcessingViewModel: Batch callback called - batch 8/10
OCRProcessingViewModel: Batch callback called - batch 9/10
OCRProcessingViewModel: Batch callback called - batch 10/10
OCRProcessingViewModel: extractImagesBatch completed, collected 10 batches
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchProcessingWithEnhancedFormatting]' passed (0.013 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchSizeCalculationForLargeFile]' started.
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=120
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=120
OCRProcessingViewModel: Got page count: 120
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 120 pages
OCR Batch Processing: pageCount=120, memoryBasedSize=50, countBasedSize=12, optimal=12
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 12
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/10
OCRProcessingViewModel: Batch callback called - batch 2/10
OCRProcessingViewModel: Batch callback called - batch 3/10
OCRProcessingViewModel: Batch callback called - batch 4/10
OCRProcessingViewModel: Batch callback called - batch 5/10
OCRProcessingViewModel: Batch callback called - batch 6/10
OCRProcessingViewModel: Batch callback called - batch 7/10
OCRProcessingViewModel: Batch callback called - batch 8/10
OCRProcessingViewModel: Batch callback called - batch 9/10
OCRProcessingViewModel: Batch callback called - batch 10/10
OCRProcessingViewModel: extractImagesBatch completed, collected 10 batches
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=500
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=500
OCRProcessingViewModel: Got page count: 500
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 500 pages
OCR Batch Processing: pageCount=500, memoryBasedSize=50, countBasedSize=30, optimal=30
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 30
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/17
OCRProcessingViewModel: Batch callback called - batch 2/17
OCRProcessingViewModel: Batch callback called - batch 3/17
OCRProcessingViewModel: Batch callback called - batch 4/17
OCRProcessingViewModel: Batch callback called - batch 5/17
OCRProcessingViewModel: Batch callback called - batch 6/17
OCRProcessingViewModel: Batch callback called - batch 7/17
OCRProcessingViewModel: Batch callback called - batch 8/17
OCRProcessingViewModel: Batch callback called - batch 9/17
OCRProcessingViewModel: Batch callback called - batch 10/17
OCRProcessingViewModel: Batch callback called - batch 11/17
OCRProcessingViewModel: Batch callback called - batch 12/17
OCRProcessingViewModel: Batch callback called - batch 13/17
OCRProcessingViewModel: Batch callback called - batch 14/17
OCRProcessingViewModel: Batch callback called - batch 15/17
OCRProcessingViewModel: Batch callback called - batch 16/17
OCRProcessingViewModel: Batch callback called - batch 17/17
OCRProcessingViewModel: extractImagesBatch completed, collected 17 batches
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchSizeCalculationForLargeFile]' passed (0.512 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchSizeCalculationForMediumFile]' started.
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=200
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=200
OCRProcessingViewModel: Got page count: 200
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 200 pages
OCR Batch Processing: pageCount=200, memoryBasedSize=50, countBasedSize=20, optimal=20
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 20
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/10
OCRProcessingViewModel: Batch callback called - batch 2/10
OCRProcessingViewModel: Batch callback called - batch 3/10
OCRProcessingViewModel: Batch callback called - batch 4/10
OCRProcessingViewModel: Batch callback called - batch 5/10
OCRProcessingViewModel: Batch callback called - batch 6/10
OCRProcessingViewModel: Batch callback called - batch 7/10
OCRProcessingViewModel: Batch callback called - batch 8/10
OCRProcessingViewModel: Batch callback called - batch 9/10
OCRProcessingViewModel: Batch callback called - batch 10/10
OCRProcessingViewModel: extractImagesBatch completed, collected 10 batches
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testBatchSizeCalculationForMediumFile]' passed (0.504 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testLargePDFUsesBatchProcessing]' started.
/Users/sunil/Desktop/OCRMax/OCRMaxTests/Integration/BatchProcessingIntegrationTests.swift:110: error: -[OCRMaxTests.BatchProcessingIntegrationTests testLargePDFUsesBatchProcessing] : XCTAssertEqual failed: ("0") is not equal to ("1")
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testLargePDFUsesBatchProcessing]' failed (0.005 seconds).
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testSmallPDFUsesStandardProcessing]' started.
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=150
OCRProcessingViewModel: Got page count: 150
OCRProcessingViewModel: Using batch processing (pageCount > 100)
OCRProcessingViewModel: Starting batch processing for 150 pages
OCR Batch Processing: pageCount=150, memoryBasedSize=50, countBasedSize=15, optimal=15
OCRProcessingViewModel: About to call extractImagesBatch with batchSize 15
MockPDFProcessor.extractImagesBatch called, count now: 1
OCRProcessingViewModel: Batch callback called - batch 1/10
OCRProcessingViewModel: Batch callback called - batch 2/10
OCRProcessingViewModel: Batch callback called - batch 3/10
OCRProcessingViewModel: Batch callback called - batch 4/10
OCRProcessingViewModel: Batch callback called - batch 5/10
OCRProcessingViewModel: Batch callback called - batch 6/10
OCRProcessingViewModel: Batch callback called - batch 7/10
OCRProcessingViewModel: Batch callback called - batch 8/10
OCRProcessingViewModel: Batch callback called - batch 9/10
OCRProcessingViewModel: Batch callback called - batch 10/10
OCRProcessingViewModel: extractImagesBatch completed, collected 10 batches
=== testSmallPDFUsesStandardProcessing: Starting ===
testSmallPDFUsesStandardProcessing: Set mockPageCount to 50
testSmallPDFUsesStandardProcessing: extractImagesCallCount=0, extractImagesBatchCallCount=0, instance: ObjectIdentifier(0x000060000291c700)
/Users/sunil/Desktop/OCRMax/OCRMaxTests/Integration/BatchProcessingIntegrationTests.swift:89: error: -[OCRMaxTests.BatchProcessingIntegrationTests testSmallPDFUsesStandardProcessing] : XCTAssertEqual failed: ("0") is not equal to ("1")
Test Case '-[OCRMaxTests.BatchProcessingIntegrationTests testSmallPDFUsesStandardProcessing]' failed (0.014 seconds).
Test Suite 'BatchProcessingIntegrationTests' failed at 2025-07-29 18:11:09.918.
	 Executed 10 tests, with 5 failures (0 unexpected) in 5.119 (5.122) seconds
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=50
MockPDFProcessor.getPageCount called: shouldSucceed=true, mockPageCount=50
OCRProcessingViewModel: Got page count: 50
OCRProcessingViewModel: Using standard processing (pageCount <= 100)
OCRProcessingViewModel: Starting standard processing
OCRProcessingViewModel: About to call pdfProcessor.extractImages
MockPDFProcessor.extractImages called, count now: 1, instance: ObjectIdentifier(0x000060000291c700)
OCRProcessingViewModel: extractImages returned 50 images