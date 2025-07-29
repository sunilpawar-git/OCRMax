//
//  PersistenceTests.swift
//  OCRMaxTests
//
//  Created by Sunil Pawar on 29/07/25.
//

import XCTest
import CoreData
@testable import OCRMax

final class PersistenceTests: XCTestCase {

    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Container Tests
    
    func testPersistentContainerCreation() {
        XCTAssertNotNil(persistenceController.container)
        XCTAssertEqual(persistenceController.container.name, "OCRMax")
    }
    
    func testInMemoryConfiguration() {
        let inMemoryController = PersistenceController(inMemory: true)
        let storeDescription = inMemoryController.container.persistentStoreDescriptions.first
        
        XCTAssertNotNil(storeDescription)
        XCTAssertEqual(storeDescription?.type, NSInMemoryStoreType)
    }
    
    func testViewContextConfiguration() {
        let context = persistenceController.container.viewContext
        
        XCTAssertNotNil(context)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent)
    }
    
    // MARK: - Shared Instance Tests
    
    func testSharedInstance() {
        let shared1 = PersistenceController.shared
        let shared2 = PersistenceController.shared
        
        // Since it's a struct, we're testing the container names
        XCTAssertEqual(shared1.container.name, shared2.container.name)
    }
    
    @MainActor
    func testPreviewConfiguration() {
        let preview = PersistenceController.preview
        let context = preview.container.viewContext
        
        XCTAssertNotNil(context)
        
        // Check that preview data exists
        let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
        do {
            let items = try context.fetch(fetchRequest)
            XCTAssertGreaterThan(items.count, 0, "Preview should contain sample data")
        } catch {
            XCTFail("Failed to fetch preview data: \(error)")
        }
    }
    
    // MARK: - Core Data Operations Tests
    
    func testCreateAndSaveItem() {
        let context = persistenceController.container.viewContext
        
        let item = Item(context: context)
        item.timestamp = Date()
        
        XCTAssertNotNil(item)
        XCTAssertNotNil(item.timestamp)
        
        do {
            try context.save()
            
            // Verify the item was saved
            let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
            let items = try context.fetch(fetchRequest)
            
            XCTAssertEqual(items.count, 1)
            XCTAssertEqual(items.first?.timestamp, item.timestamp)
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
    }
    
    func testFetchItems() {
        let context = persistenceController.container.viewContext
        
        // Create test items
        for i in 0..<5 {
            let item = Item(context: context)
            item.timestamp = Date().addingTimeInterval(TimeInterval(i))
        }
        
        do {
            try context.save()
            
            let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
            let items = try context.fetch(fetchRequest)
            
            XCTAssertEqual(items.count, 5)
        } catch {
            XCTFail("Failed to fetch items: \(error)")
        }
    }
    
    func testDeleteItem() {
        let context = persistenceController.container.viewContext
        
        let item = Item(context: context)
        item.timestamp = Date()
        
        do {
            try context.save()
            
            // Verify item exists
            let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
            var items = try context.fetch(fetchRequest)
            XCTAssertEqual(items.count, 1)
            
            // Delete the item
            context.delete(item)
            try context.save()
            
            // Verify item is deleted
            items = try context.fetch(fetchRequest)
            XCTAssertEqual(items.count, 0)
        } catch {
            XCTFail("Failed during delete operation: \(error)")
        }
    }
    
    // MARK: - Context Configuration Tests
    
    func testViewContextProperties() {
        let context = persistenceController.container.viewContext
        
        XCTAssertTrue(context.automaticallyMergesChangesFromParent)
        XCTAssertNotNil(context.mergePolicy)
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveWithoutChanges() {
        let context = persistenceController.container.viewContext
        
        // Saving without changes should not throw an error
        XCTAssertNoThrow(try context.save())
    }
    
    func testContextRollback() {
        let context = persistenceController.container.viewContext
        
        let item = Item(context: context)
        item.timestamp = Date()
        
        // Verify item exists in context
        XCTAssertTrue(context.hasChanges)
        
        // Rollback changes
        context.rollback()
        
        // Verify changes are rolled back
        XCTAssertFalse(context.hasChanges)
        
        // Verify item is not saved
        let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
        do {
            let items = try context.fetch(fetchRequest)
            XCTAssertEqual(items.count, 0)
        } catch {
            XCTFail("Failed to fetch items after rollback: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeDataSetPerformance() {
        let context = persistenceController.container.viewContext
        
        measure {
            for i in 0..<1000 {
                let item = Item(context: context)
                item.timestamp = Date().addingTimeInterval(TimeInterval(i))
            }
            
            do {
                try context.save()
            } catch {
                XCTFail("Failed to save large dataset: \(error)")
            }
        }
    }
}