## 🎯 **Test Fixing Roadmap**

### **Phase 1: Infrastructure & Mocking Foundation**
1. **Fix test infrastructure and mocking framework issues**
   - Update mock service interfaces to match current protocols
   - Fix constructor parameter mismatches in test setup
   - Ensure all mock dependencies are properly initialized

2. **Update test constructors to match actual interface signatures**
   - OCRViewModel constructor in tests uses fewer parameters than actual implementation
   - Fix FormattingOptionsViewModel test setup
   - Update integration test dependency injection

3. **Fix mock service implementations to properly support all required methods**
   - MockOCRService missing some protocol methods
   - MockSubscriptionManager feature detection logic
   - MockAIFormattingService parameter validation

### **Phase 2: Core Test Pattern Fixes**
4. **Fix async test timing and await patterns for reliability**
   - Replace polling with proper async/await patterns
   - Fix race conditions in processing state checks
   - Standardize timeout handling across tests

5. **Fix integration test setup and dependency injection**
   - Fix complex dependency injection in OCRIntegrationTests
   - Ensure proper mock configuration for end-to-end flows
   - Fix subscription state management in integration tests

### **Phase 3: Service-Specific Fixes**
6. **Fix individual service test cases and expectations**
   - VisionOCRService test environment issues
   - TesseractOCRService configuration problems
   - DocumentExportService format validation
   - LayoutAnalyzer test data setup

7. **Fix subscription and premium feature test scenarios**
   - SubscriptionManager mock state management
   - Feature access validation logic
   - Purchase flow test scenarios
   - AI service cost estimation tests

### **Phase 4: Validation**
8. **Run full test suite to validate all fixes are working**
   - Execute complete test suite
   - Verify all 128 tests pass
   - Address any remaining edge cases
   - Document test coverage improvements

## 🔍 **Key Issues Identified:**

### **Interface Mismatches:**
- `OCRViewModel` constructor in tests is missing 3 parameters that exist in the actual implementation
- Mock services don't implement all required protocol methods
- Subscription manager mock feature detection logic is incomplete

### **Async Testing Problems:**
- Tests use polling loops instead of proper async/await
- Race conditions in `isProcessing` state checks
- Inconsistent timeout handling

### **Mock Service Issues:**
- `MockOCRService` and `MockEnhancedOCRService` interface inconsistencies
- `MockSubscriptionManager` missing proper feature validation
- `MockAIFormattingService` parameter handling problems

### **Integration Test Complexity:**
- Complex dependency injection setup needs simplification
- End-to-end test flows missing proper mock configuration
- State management issues across multiple services

## 🛠 **Recommended Approach:**

1. **Start with Infrastructure (Phase 1)** - Fix the foundation first
2. **Address Async Patterns (Phase 2)** - Stabilize test reliability  
3. **Service-by-Service Fixes (Phase 3)** - Systematic service test fixes
4. **Comprehensive Validation (Phase 4)** - Ensure complete success

This systematic approach will address the 36 failing tests by fixing root causes rather than individual symptoms. Each phase builds on the previous one, ensuring a stable foundation for the subsequent fixes.