# GEMINI.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Mandatory Context

BEFORE implementing any task, you MUST read the files in the `project_context/` directory carefully to understand the project: architecture.md (fvm, flutter, provider, services, singletons, repositories, init flow), context.md (what the app does, where to find files and logic), and coding_style.md (simplicity, avoid complex code, existing patterns). Use this understanding to implement any feature correctly.

**Living Docs Mandate:** You MUST keep the documentation in `docs/features/` updated as you implement or modify features. If a feature's behavior or technical flow changes, its corresponding markdown file must be updated. If a new feature is created, a new document must be added to `docs/features/` following the existing format.

## Project-Specific Instructions

- Use `fvm` for all Flutter/Dart commands.
- Prioritize simplicity and avoid over-engineering.
- Maintain the established service and provider patterns.

## Testing

Always run tests before committing:

- `fvm flutter test`

## Commands

When a user uses a slash command (e.g., `/pm:epic-run`), refer to the following locations for instructions:

- `/pm:*`: `.gemini/commands/pm/`
- General commands: `.gemini/commands/`

## Code Style

Follow existing patterns in the codebase.
