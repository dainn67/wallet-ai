<!-- Source: Architecture decisions | Collected: 2026-03-17T07:19:03Z | Epic: record-provider -->

# Architecture Decisions

## Architecture Decisions

### AD-1: ChangeNotifier with Repository Delegation
**Context:** We need a reactive layer over the existing `RecordRepository`.
**Decision:** Implement `RecordProvider` as a `ChangeNotifier` that holds in-memory lists of `Record` and `MoneySource`.
**Alternatives rejected:** Using `FutureProvider` or `StreamProvider` directly with SQLite. These are harder to manage for complex filtering and manual CRUD operations compared to a central `ChangeNotifier`.
**Trade-off:** In-memory state must be carefully synced with the database to avoid "stale" data, but it provides instant UI updates and easy filtering.
**Reversibility:** Easy - the logic remains encapsulated in the provider.

### AD-2: ProxyProvider for Cross-Provider Sync
**Context:** `ChatProvider` saves records to the database, but `RecordProvider` needs to know when this happens to refresh its state.
**Decision:** Use `ChangeNotifierProxyProvider<ChatProvider, RecordProvider>` in `main.dart`. The `update` method will be used to trigger a `loadAll()` in `RecordProvider` when `ChatProvider` indicates a change (e.g., via a simple counter or timestamp).
**Alternatives rejected:** Event bus, global static listeners, or passing `RecordProvider` into `ChatProvider` constructor (circular dependency risk).
**Trade-off:** Adds a dependency between providers in the widget tree, but is the idiomatic `provider` way to handle cross-state updates.
**Reversibility:** Moderate - requires refactoring `main.dart` provider setup.

