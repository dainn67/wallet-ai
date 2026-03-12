<!-- Source: Architecture decisions | Collected: 2026-03-12T07:46:45Z | Epic: setup-provider -->

# Architecture Decisions

## Architecture Decisions
### AD-1: Use Provider for State Management
**Context:** The app needs a way to share state and logic across widgets.
**Decision:** Use the `provider` package.
**Alternatives rejected:** `Riverpod` (too complex for initial MVP), `Bloc` (high boilerplate).
**Trade-off:** Simple to learn and use, but can lead to performance issues if `watch` is overused on large widget trees.
**Reversibility:** Moderate - switching to Riverpod later is possible but requires refactoring.

### AD-2: Root-level MultiProvider
**Context:** Multiple features will eventually need global state (Auth, Wallet, Settings).
**Decision:** Wrap the `MaterialApp` in a `MultiProvider` in `main.dart`.
**Alternatives rejected:** Individual providers wrapped around specific screens (leads to "provider hunting" and nesting).
**Trade-off:** Slightly more global state than strictly necessary, but much cleaner for scaling.
**Reversibility:** Easy.

