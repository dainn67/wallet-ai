---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Project Style Guide

## Core Principles
1. **Simplicity beats cleverness.** Choose the most direct solution; avoid over-engineering. Three readable lines beat a premature abstraction.
2. **Follow existing patterns.** Match the codebase's singleton style, provider usage, repository and model patterns before introducing anything new.
3. **No comments unless the *why* is non-obvious.** Well-named identifiers explain *what*; comments are reserved for hidden constraints, subtle invariants, or workarounds.
4. **Minimal boilerplate.** Reuse `ApiHelper` for HTTP; reuse `ApiService` for endpoint config; reuse barrel exports for imports.

## Naming
- **Files**: `snake_case.dart`.
- **Classes / Types**: `UpperCamelCase`.
- **Members, locals, parameters**: `lowerCamelCase`.
- **Private members**: `_leadingUnderscore`.
- **Constants**: `lowerCamelCase` (`partialDelimiter`, `keyUserPattern`), not `SCREAMING_SNAKE`.
- **Booleans**: prefer `is…` / `has…` / `should…` prefixes (`isStreaming`, `hasStartedStreaming`, `displayTextCompleted`).
- **Async methods**: verb + noun (`sendMessage`, `loadAll`, `updateUserPattern`).

## File Organization
- One public class/widget per file; helpers may live in the same file when tightly coupled.
- Every leaf directory exposes a barrel file (`<dir>.dart`) re-exporting its public surface.
- External imports go through the barrel: `import 'package:wallet_ai/providers/providers.dart';`.

## State Management
- **Provider** is for *reactive UI state only*.
- **Services and repositories** are singletons that own the actual data and logic.
- Use `context.read<T>()` for one-shot actions; `Consumer<T>` / `context.watch<T>()` for reactive rebuilds.
- Never reach into a singleton service through a provider just to make it "injectable" — singletons are called directly.

## Singletons
```dart
class XService {
  XService._();
  static final XService _instance = XService._();
  factory XService() => _instance;
}
```
Async init runs in `main()` before `runApp` (`StorageService.init()`, `RecordRepository.init()`, `dotenv.load()`).

## Async / Streams
- **Delimited responses** (chat): UI stops rendering at the first `--//--`; background parsing continues until the stream closes.
- **No silent error swallowing.** Surface in UI (SnackBar / banner) or rethrow; don't catch and ignore.
- **Cancel streams in `dispose`** — see `ChatProvider._streamSubscription?.cancel()`.
- **Fire-and-forget** is fine for background jobs (`AiPatternService().updateUserPattern()`); don't `await` them inside `main()` if they're not on the critical init path.

## Networking
- All HTTP goes through `ApiService` (or a service that wraps it). Never call `ApiHelper` directly from a feature.
- URLs and endpoint paths live in `ApiConfig`. Auth and base URLs in `AppConfig` (from `.env`).
- **No hardcoded secrets**, ever. Add new keys to `.env.example` and read them via `AppConfig`.

## UI Conventions
- **Material 3** + Poppins font (local asset only — `google_fonts` is prohibited).
- **Colors** mostly via `Theme.of(context).colorScheme.*`; literal hex only for one-off neutrals (`0xFFF1F5F9`) and pre-existing patterns.
- **Padding**: `EdgeInsets.all/symmetric/only(…)` with 4/8/12/16/20/24px increments; avoid odd numbers.
- **Borders**: `BorderRadius.circular(16)` for cards/sheets, `circular(24)` for input pills, `circular(12)` for chips — match what already exists.
- **`ScrollController`**: prefer `jumpTo` over `animateTo` when the trigger can fire rapidly (e.g., streaming chunks). Reserve `animateTo` for user-initiated, single-shot scrolls.

## Repository / Data Patterns
- Wrap balance-affecting work in `db.transaction { ... }`. Use `RecordRepository._applyRecordImpact` rather than reimplementing source-balance math.
- Schema changes go through `lib/services/record_migration_service.dart` with backfill — never destructive in-place migrations.
- Transient model fields (e.g., `Record.suggestedCategory`) must be excluded from `toMap()` / `fromMap()`.

## Testing
- Every service or provider has a corresponding test file under `test/` (1:1 with `lib/`).
- Run `fvm flutter test` before committing.
- Use `mocktail` for mocks; inject via factory constructors or `setMock…` hooks (e.g., `RecordRepository.setMockDatabase`).
- Epic-level e2e / integration tests live under `tests/e2e/epic_<name>/` and `tests/integration/epic_<name>/`.

## Documentation
- **`docs/features/<slug>.md`** — must be updated whenever the feature's behavior or technical flow changes; new features get a new file in the existing format.
- **`project_context/architecture.md|context.md|coding_style.md`** — must be updated when features complete or architecture shifts.
- README is regenerated from context; don't hand-edit unless adding manually maintained sections.

## Don'ts
- ❌ `google_fonts` (FOUT risk).
- ❌ Hardcoded keys, URLs, or environment-specific config in source.
- ❌ Manual balance arithmetic in UI / providers (use repo helpers).
- ❌ New design patterns when an existing one fits.
- ❌ Commentary comments ("// loop through records") — code should speak.
- ❌ Catch-and-ignore error handlers.
- ❌ Imports that bypass the barrel file for first-party code.

## Git
- Commits should be small and focused. Conventional-ish messages: `feat:`, `fix:`, `refactor:`, `chore:`, optionally scoped (`feat(locale): …`).
- Issue-scoped commits: `Issue #N: <description>`.
- Branches: `epic/<slug>` for multi-PR work; ad-hoc fixes can go direct to `main` via PR.
