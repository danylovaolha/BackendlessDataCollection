//
//  BackendlessDataCollection.swift
//
/*
 * *********************************************************************************************************************
 *
 *  BACKENDLESS.COM CONFIDENTIAL
 *
 *  ********************************************************************************************************************
 *
 *  Copyright 2020 BACKENDLESS.COM. All Rights Reserved.
 *
 *  NOTICE: All information contained herein is, and remains the property of Backendless.com and its suppliers,
 *  if any. The intellectual and technical concepts contained herein are proprietary to Backendless.com and its
 *  suppliers and may be covered by U.S. and Foreign Patents, patents in process, and are protected by trade secret
 *  or copyright law. Dissemination of this information or reproduction of this material is strictly forbidden
 *  unless prior written permission is obtained from Backendless.com.
 *
 *  ********************************************************************************************************************
 */

import Foundation
import SwiftSDK

@objc public protocol Identifiable {
    var objectId: String? { get set }
}


@objc public enum EventType: Int {
    case dataLoaded
    case created
    case updated
    case deleted
    case bulkDeleted
}


@objcMembers public class BackendlessDataCollection: Collection {
    
    public typealias BackendlessDataCollectionType = [Identifiable]
    public typealias Index = BackendlessDataCollectionType.Index
    public typealias Element = BackendlessDataCollectionType.Element
    public typealias RequestStartedHandler = () -> Void
    public typealias RequestCompletedHandler = () -> Void
    public typealias BackendlessFaultHandler = (Fault) -> Void
    
    public var startIndex: Index { return backendlessCollection.startIndex }
    public var endIndex: Index { return backendlessCollection.endIndex }
    public var requestStartedHandler: RequestStartedHandler?
    public var requestCompletedHandler: RequestCompletedHandler?
    public var errorHandler: BackendlessFaultHandler?
    
    public private(set) var whereClause = ""
    public private(set) var count: Int {
        get { return backendlessCollection.count }
        set { }
    }
    public private(set) var isEmpty: Bool {
        get { return backendlessCollection.isEmpty }
        set { }
    }
    
    private var backendlessCollection = BackendlessDataCollectionType()
    private var entityType: AnyClass!
    private var dataStore: DataStoreFactory!
    private var queryBuilder: DataQueryBuilder!
    
    private enum CollectionErrors {
        static let invalidType = " is not a type of objects contained in this collection."
        static let nullObjectId = "objectId is null."
    }
    
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    public subscript (position: Int) -> Identifiable {        
        if position >= backendlessCollection.count {
            fatalError("Index out of range")
        }
        if queryBuilder.getOffset() == backendlessCollection.count {
            return backendlessCollection[position]
        }
        else if position < queryBuilder.getOffset() - 2 * queryBuilder.getPageSize() {
            return backendlessCollection[position]
        }
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            self.loadNextPage()
            semaphore.signal()
        }
        semaphore.wait()
        return backendlessCollection[position]
    }
    
    private init() { }
    
    public convenience init(entityType: AnyClass) {
        let dataQueryBuilder = DataQueryBuilder()
        dataQueryBuilder.setPageSize(pageSize: 50)
        dataQueryBuilder.setOffset(offset: 0)
        self.init(entityType: entityType, queryBuilder: dataQueryBuilder)
    }
    
    public convenience init(entityType: AnyClass, queryBuilder: DataQueryBuilder) {
        self.init()
        self.queryBuilder = queryBuilder
        self.dataStore = Backendless.shared.data.of(entityType.self)
        self.entityType = entityType
        self.whereClause = self.queryBuilder.getWhereClause() ?? ""
        self.count = getRealCount()
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            var pagesCount = 1
            if self.count > queryBuilder.getPageSize() {
                pagesCount = 2
            }
            for _ in 0 ..< pagesCount {
                self.loadNextPage()
            }
            semaphore.signal()
        }
        semaphore.wait()
        return
    }
    
    deinit {
        dataStore.rt.removeAllListeners()
    }
    
    // Adds a new element to the Backendless collection
    public func add(newObject: Any) {
        checkObjectType(object: newObject)
        backendlessCollection.append(newObject as! Identifiable)
        queryBuilder.setOffset(offset: queryBuilder.getOffset() + 1)
    }
    
    // Adds the elements of a sequence to the Backendless collection
    public func add(contentsOf: [Any]) {
        for object in contentsOf {
            add(newObject: object)
        }
    }
    
    // Inserts a new element into the Backendless collection at the specified position
    public func insert(newObject: Any, at: Int) {
        checkObjectType(object: newObject)
        backendlessCollection.insert(newObject as! Identifiable, at: at)
        queryBuilder.setOffset(offset: queryBuilder.getOffset() + 1)
    }
    
    // Inserts the elements of a sequence into the Backendless collection at the specified position
    public func insert(contentsOf: [Any], at: Int) {
        var index = at
        for newObject in contentsOf {
            insert(newObject: newObject, at: index)
            index += 1
        }
    }
    
    // Removes object from the Backendless collection
    public func remove(object: Any) {
        checkObjectTypeAndId(object: object)
        let objectId = (object as! Identifiable).objectId
        backendlessCollection.removeAll(where: { $0.objectId == objectId })
        queryBuilder.setOffset(offset: queryBuilder.getOffset() - 1)
    }
    
    // Removes and returns the element at the specified position
    public func remove(at: Int) -> Identifiable {
        let object = backendlessCollection[at]
        remove(object: object)
        return object
    }
    
    // Removes all the elements from the Backendless collection that satisfy the given slice
    
    public func removeAll(where shouldBeRemoved: (Identifiable) throws -> Bool) rethrows {
        try backendlessCollection.removeAll(where: shouldBeRemoved)
    }
    
    public func removeAll() {
        self.backendlessCollection.removeAll()
    }
    
    public func makeIterator() -> IndexingIterator<BackendlessDataCollectionType> {
        return backendlessCollection.makeIterator()
    }
    
    public func sort(by: (Identifiable, Identifiable) throws -> Bool) {
        do {
            backendlessCollection = try backendlessCollection.sorted(by: by)
        }
        catch {
            return
        }
    }
    
    // private functions
    
    private func getRealCount() -> Int {
        var realCount = 0
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            self.queryBuilder.setWhereClause(whereClause: self.whereClause)
            self.dataStore.getObjectCount(queryBuilder: self.queryBuilder, responseHandler: { totalObjects in
                realCount = totalObjects
                semaphore.signal()
            }, errorHandler: { fault in
                semaphore.signal()
                self.errorHandler?(fault)
            })
        }
        semaphore.wait()
        return realCount
    }
    
    private func checkObjectType(object: Any) {
        if entityType != type(of: object) {
            fatalError("\(type(of: object))" + CollectionErrors.invalidType)
        }
    }
    
    private func checkObjectTypeAndId(object: Any) {
        checkObjectType(object: object)
        if (object as! Identifiable).objectId == nil {
            fatalError(CollectionErrors.nullObjectId)
        }
    }
    
    private func loadNextPage() {
        let semaphore = DispatchSemaphore(value: 0)
        var offset = queryBuilder.getOffset()
        if !whereClause.isEmpty {
            queryBuilder.setWhereClause(whereClause: whereClause)
        }
        dataStore.find(queryBuilder: queryBuilder, responseHandler: { [weak self] foundObjects in
            guard let self = self else {
                semaphore.signal()
                return
            }
            guard let foundObjects = foundObjects as? [Identifiable] else {
                semaphore.signal()
                return
            }
            self.backendlessCollection += foundObjects
            offset += foundObjects.count
            
            if self.queryBuilder.getOffset() < self.count {
                self.queryBuilder.setOffset(offset: offset)
            }
            semaphore.signal()
            }, errorHandler: { [weak self] fault in
                semaphore.signal()
                self?.errorHandler?(fault)
        })
        semaphore.wait()
    }
}
