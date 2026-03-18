# Expense Records Feature Documentation

## Technical Overview
The Expense Records feature handles the persistence and management of financial transactions, including income and expenses. It is backed by a local SQLite database and synchronized through a reactive provider layer to update the UI in real-time.

## Technical Mapping

### UI Layer
- **RecordsTab**: Displays the list of financial transactions and summary metrics (total income, spent). Uses `Consumer<RecordProvider>` to listen for changes.

### Provider Layer
- **RecordProvider**: Acts as the central state manager for the records and money sources.
  - `loadAll()`: Fetches all data from the repository on initialization.
  - `addRecord(record)`: Orchestrates the creation of a new record through the repository.
  - `updateRecord(record)`, `deleteRecord(id)`: Handle standard CRUD logic with state synchronization.
  - `filteredRecords`: Reactive getter providing filtered and sorted records to the UI.

### Repository Layer
- **RecordRepository**: Direct interface with the local SQLite database.
  - `init()`: Handles the initialization, asset-to-document migration, and schema management.
  - `createRecord(record)`: Executes a database transaction that both inserts the new record and adjusts the associated `MoneySource` balance.
  - `getAllRecords()`, `getAllMoneySources()`: Query methods for retrieving bulk data.

### Database Layer
- **SQLite Database**: The underlying persistent store (`data.db`).
  - Tables: `record`, `MoneySource`.
  - Trigger logic (simulated in repository via transactions) ensures that every transaction is correctly reflected in source balances.

## Flow Diagram

```mermaid
sequenceDiagram
    participant UI as RecordsTab
    participant RP as RecordProvider
    participant RR as RecordRepository
    participant DB as SQLite (sqflite)

    UI->>RP: Consumer (Accesses state)
    RP->>RR: loadAll() (Init)
    RR->>DB: query('record'), query('MoneySource')
    DB-->>RR: Raw Data
    RR-->>RP: List<Record>, List<MoneySource>
    RP-->>UI: notifyListeners() (Render data)

    Note over UI: User creates new record
    UI->>RP: addRecord(record)
    RP->>RR: createRecord(record)
    
    activate RR
    RR->>DB: transaction (Start)
    RR->>DB: insert('record')
    RR->>DB: update('MoneySource') (Adjust balance)
    RR->>DB: commit (End)
    deactivate RR
    
    RR-->>RP: record_id
    RP->>RP: update _records list
    RP-->>UI: notifyListeners() (Refresh View)
```
