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
2. people = BackendlessDataCollection(entityType: Person.self, whereClause: "age > 20")
```

## Description

#### `BackendlessDataCollection(entityType: Person.self)`
Create ordinary collection for table _Person_ which reflects all records from it.
- the total size of objects (table rows) is retrieved on object creation;
- you can iterate through the entire collection;
- every iteration will perform calls to the Backendless server;
- all `add`,  `insert` and `remove` operations directly perform calls to Backendless server;

#### `BackendlessDataCollection(entityType: Person.self, whereClause: "age > 20")`
Create collection as a slice of data for table _Person_. Will reflect only a subset of data which satisfy argument `whereClause` (in or case it `age > 20`).\
Main features are the same as in point (1).
- the total size of objects satisfied the _whereClause_ is retrieved on object creation;
- you can iterate only through the subset of objects;
- all `add`,  `insert` and `remove` operations directly perform calls to Backendless server and would be discarded if the object doesn't match the where clause;

## Properties and special functions

**`count`** - returns the total number of the Backendless collection elements which reflect the row size in the underlying table.

**`isEmpty`** - never makes api call to Backendless. Returns _true_ if Backendless collection is empty.

**`whereClause`** - returns where clause for the current collection or empty string if it was created without whereClause.

**`populate()`** - forcibly populates current collection from the Backendless data table (greedy initialization). Under the hood it just iterate over remote table.

**`isLoaded()`** - returns _true_ if the data was retrieved from Backendless table in a full (after invocation `populate()` function or full iteration).

**`add()`, `add(contentsOf: )`, `insert()`, `insert(contentsOf: )`, `remove()`, `remove(at: )`, `removeAll()`** - always perfrom api calls to Backendless to synchronize local state and remote table.

## Handlers

The handlers below can be used to work with UI components - reloading tableView, showing activity indicator etc.
```
public typealias RequestStartedHandler = () -> Void
public typealias RequestCompletedHandler = () -> Void
public typealias BackendlessFaultHandler = (Fault) -> Void
public typealias BackendlessDataChangedHandler = (EventType) -> Void
```
`public var requestStartedHandler: RequestStartedHandler?` - indicates when the request to server starts.
`public var requestCompletedHandler: RequestCompletedHandler?` - indicates when the request to server is completed.
`public var errorHandler: BackendlessFaultHandler?` - handles errors that may occur during requests to Backendless.
`public var dataChangedHandler: BackendlessDataChangedHandler?` - handles collection changes, e.g. adding or removing object/objects to/from the Backendless collection.

As far as BackendlessDataCollection class works in conjunction with real-time we can handle different types of data changed events - creating, updating and deleting:
```
@objc public enum EventType: Int {
    case dataLoaded
    case created
    case updated
    case deleted
    case bulkDeleted
}
```
`.dataLoaded` - is used in the `populate()` function to handle all data is loaded in one step.
`.created`, `.updated`, `.deleted`, `.bulkDeleted` - are used in the `add`,  `insert` and `remove` functions to handle changes in the Backendless table in real-time.

E.g. if we want to handle adding or removing objects in the people collection we can deal with it this way:
```
people.dataChangedHandler = { eventType in
	if eventType == .created {
    	print("Object has been created")
    }
    else if eventType == .deleted {
        print("Object has been deleted")
    }
}
```

If we want to have the same behaviour for different event types (e.g. reloading table with updated data):
```
people.dataChangedHandler = { eventType in
	self.tableView.reloadData()
}
```

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

Sample [application](https://github.com/olgadanylova/BackendlessDataCollectionSample) which demonstrates how to bind UITableView  to the BackendlessDataCollection class for automatic data loading purposes
