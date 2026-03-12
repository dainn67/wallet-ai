---
allowed-tools: Bash, Read, Write, LS
---

# Prime Testing Environment

Detect test framework and configure the test-runner agent.

## Usage
```
/testing:prime
```

## Instructions

### Step 1: Detect Framework

```bash
bash .gemini/scripts/testing/detect-framework.sh
```

If output shows `framework: none`:
- Ask user: "No test framework detected. What test command should I use? (e.g., `pytest`, `npm test`, `go test ./...`)"
- Use their answer for the config below

### Step 2: Create Testing Config

Using the detection results, create `.gemini/testing-config.md`:

```markdown
---
framework: {detected_framework}
test_command: {detected_command}
created: {run: date -u +"%Y-%m-%dT%H:%M:%SZ"}
---

# Testing Configuration

## Framework
- Type: {framework}
- Config: {config_file}

## Commands
- Run all: `{test_command}`
- Run specific file: `{test_command} {path/to/test_file}`

## Test Structure
- Directory: {test_directory}
- Files found: {test_count}

## Rules
- Always use test-runner agent from `.gemini/agents/test-runner.md`
- Verbose output for debugging
- No mocking — use real services
- Sequential execution (no parallel)
- Capture full stack traces
```

### Step 3: Validate

Run a quick validation to confirm the framework works:

```bash
# Try running with --version or --help to verify the tool exists
{test_command} --help 2>/dev/null | head -3 || echo "⚠️ Test command may not be available"
```

### Output

```
✅ Testing environment primed

Framework: {framework}
Tests found: {count} files
Config saved: .gemini/testing-config.md

Next steps:
  - Run all tests: /testing:run
  - Run specific: /testing:run {test_file}
```

$ARGUMENTS
