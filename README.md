# BackendlessDataCollection

This is an implementation of the class than conforms to the iOS/macOS Collection protocol enabling to retrieve and iterate over a collection of objects stored in a Backendless data table.</p>

Functions that returns data are mapped to various Backendless Data APIs.</p>

The Iterator returned by the implementation lets you access either all objects from the data table or a subset determined by a where clause.</p>

[Whant the examples now](https://github.com/olgadanylova/BackendlessDataCollection#examples)

All retrieved objects are saved locally to enable faster access in future iterations.\
The collection is not thread safe.

# User Guide

## Create collection
```
var people: BackendlessDataCollection?

1. people = BackendlessDataCollection(entityType: Person.self)

2. let queryBuilder = DataQueryBuilder()
   queryBuilder.setWhereClause(whereClause: "age > 20")
   people = BackendlessDataCollection(entityType: Person.self, queryBuilder: queryBuilder)
```

## Description

#### `BackendlessDataCollection(entityType: Person.self)`
Create ordinary collection for table _Person_ which reflects all records from it.
- the total size of objects (table rows) is retrieved on object creation;
- you can iterate through the entire collection;
- every iteration will perform calls to the Backendless server;
- the `add`,  `insert` and `remove` operations do not perform calls to Backendless server;

#### `BackendlessDataCollection(entityType: Person.self, queryBuilder: queryBuilder)`
Create collection as a slice of data for table _Person_. Will reflect only a subset of data which satisfy argument `whereClause` (in or case it `age > 20`).\
Main features are the same as in point (1).
- the total size of objects satisfied the _whereClause_ is retrieved on object creation;
- you can iterate only through the subset of objects;
- the `add`,  `insert` and `remove` operations do not perform calls to Backendless server;

## Properties and special functions

**`count`** - returns the total number of the Backendless collection elements which reflect the row size in the underlying table.

**`isEmpty`** - never makes api call to Backendless. Returns _true_ if Backendless collection is empty.

**`sort(by:)`**  - sorts the collection in place, using the given predicate as the comparison between elements.

**`makeIterator()`** - returns an iterator over the elements of the collection

## Handlers

The handlers below can be used to work with UI components - reloading tableView, showing activity indicator etc.
```
public typealias RequestStartedHandler = () -> Void
public typealias RequestCompletedHandler = () -> Void
public typealias BackendlessFaultHandler = (Fault) -> Void
public typealias BackendlessDataChangedHandler = (EventType) -> Void
```
**`public var requestStartedHandler: RequestStartedHandler?`** - indicates when the request to server starts.

**`public var requestCompletedHandler: RequestCompletedHandler?`** - indicates when the request to server is completed.

**`public var errorHandler: BackendlessFaultHandler?`** - handles errors that may occur during requests to Backendless.

## Examples

**for-in**
```
for person in people {
    print((person as! Person).name ?? "")
}
```

**for-in with premature break**
```
for person in people {
    print((person as! Person).name ?? "")
    if (person as! Person).name == "Bob" {
        break
    }
}
```

**for-each**
```
people.forEach({ person in
    print((person as! Person).name ?? "")
})
```

**iterator**
```
let personIterator = people.makeIterator()
while let person = personIterator.next() as? Person {
    print("\(person.objectId ?? ""), \(person.name ?? "")")
}
```
