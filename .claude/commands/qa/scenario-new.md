---
allowed-tools: [Read, Write, Bash, Glob]
---

# QA: Scenario New

Scaffold a new QA scenario file at `.claude/qa/scenarios/{name}.md`.

## Supported Keywords

### Vietnamese
- `mở` — open/launch an app or screen
- `chọn` — select/choose an element or option
- `kiểm tra` — verify/check a condition
- `vuốt` — swipe gesture

### English
- `tap` — tap a UI element
- `verify` — assert a condition is true
- `swipe` — swipe gesture
- `launch` — launch app or screen
- `type` — enter text into a field
- `check` — check a condition
- `open` — open a screen or item
- `select` — select an element or option

## Step Format

- Arrow notation: `action → assertion` (e.g., `Tap 'Login' → verify home screen displayed`)
- Quoted elements: use single quotes around UI element labels (e.g., `'Start Quiz'`)
- Steps are numbered: `1.`, `2.`, etc.

## Frontmatter Fields

| Field        | Required | Values                                                             |
|--------------|----------|--------------------------------------------------------------------|
| `name`       | yes      | kebab-case identifier                                              |
| `screens`    | yes      | array of screen names (e.g., `[HomeView, QuizView]`)              |
| `priority`   | yes      | `high`, `medium`, or `low`                                        |
| `categories` | yes      | array, subset of: `ui_layout`, `navigation_flow`, `data_display`, `accessibility` |

## Instructions

1. **Get scenario name:**
   - If `$ARGUMENTS` is non-empty, use it as the scenario name.
   - Otherwise, ask: `Enter scenario name (kebab-case, e.g. "login-flow"):`
   - Validate: name MUST match `^[a-z0-9][a-z0-9-]*[a-z0-9]$`. If invalid → print `❌ Name must be kebab-case (e.g. "login-flow"). Got: '{name}'` and stop.

2. **Check for duplicate:**
   - If `.claude/qa/scenarios/{name}.md` exists → ask: `⚠️ Scenario '{name}' already exists. Overwrite? (yes/no)`
   - If no → stop.

3. **Collect metadata:**
   Ask the user for:
   - **Target screens** (comma-separated, e.g., `HomeView, LoginView`)
   - **Priority** (`high`, `medium`, or `low`)
   - **Categories** (comma-separated from: `ui_layout`, `navigation_flow`, `data_display`, `accessibility`)
   - Validate categories — warn and filter out any values not in the valid set.
   - At least one category is required.

4. **Collect steps:**
   - Ask: `Describe the test steps (numbered list, or press Enter to use template):`
   - If user provides steps, use them.
   - If empty, use the template steps below.
   - At least 1 step is required. If none provided and user skips template → print `❌ At least one step is required.` and stop.

5. **Ensure directory:**
   ```bash
   mkdir -p .claude/qa/scenarios 2>/dev/null
   ```

6. **Write scenario file** to `.claude/qa/scenarios/{name}.md`:

```markdown
---
name: {name}
screens: [{screen1}, {screen2}]
priority: {priority}
categories: [{cat1}, {cat2}]
---
# {Title Case of name}
{numbered steps}
```

**Template steps** (used when user skips step input):
```
1. Mở app → verify main screen visible
2. Tap '{Primary Action}' → verify expected screen displayed
3. Kiểm tra key elements visible on screen
4. Verify data displayed correctly
5. Tap back → verify returns to previous screen
```

7. **Confirm:**
   ```
   ✅ Scenario created: .claude/qa/scenarios/{name}.md
   Next: /qa:run {name}
   ```
