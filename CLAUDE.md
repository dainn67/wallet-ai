# CLAUDE.md

Think carefully and implement the most concise solution that changes as little code as possible.

## Mandatory Context

BEFORE implementing any task, you MUST read the files in the `project_context/` directory carefully to understand the project: architecture.md (fvm, flutter, provider, services, singletons, repositories, init flow), context.md (what the app does, where to find files and logic), and coding_style.md (simplicity, avoid complex code, existing patterns). Use this understanding to implement any feature correctly.

**Living Docs Mandate:** You MUST keep both the user-facing documentation in `docs/features/` and the developer-focused context in `project_context/` updated.
- **`docs/features/`**: If a feature's behavior or technical flow changes, its corresponding markdown file must be updated. If a new feature is created, a new document must be added following the existing format.
- **`project_context/`**: Files like `architecture.md`, `context.md`, and `coding_style.md` MUST be updated whenever a new feature is completed or a significant architectural change or fix is made. These are the core source of truth.

## Project-Specific Instructions

- Use `fvm` for all Flutter/Dart commands.
- Prioritize simplicity and avoid over-engineering.
- Maintain the established service and provider patterns.

## Server Context

The server codebase is located in the parent directory: `../chatbot-flow-server/`.
- **Documentation**: To understand server-side features, prompts, or API logic, you MUST read the files in `../chatbot-flow-server/docs/` (architecture.md, context.md, coding_style.md) and `../chatbot-flow-server/docs/features/`.
- **Scope**: The server handles multiple projects (AIKaze, LinguaAI, Math Bear, WalletAI). You MUST focus only on logic related to **WalletAI** (wallyai).

## Commands

When a user uses a slash command (e.g., `/pm:epic-run`), refer to the following locations for instructions:

- `/pm:*`: `.gemini/commands/pm/`
- General commands: `.gemini/commands/`
