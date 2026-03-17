# WRITE TESTS FROM PHASE A REPORT — Phase B Preparation

You are writing smoke and integration tests for epic `{epic_name}` based on the Phase A Semantic Review report.

## Context

- Phase A report: `.claude/context/verify/epic-reports/{report_file}`
- Epic name: `{epic_name}`

## Instructions

### 1. Read Phase A Report

Read the Phase A report and extract these sections:
- **"Phase B Preparation"** → contains E2E Test Scenarios, Integration Test Points, Smoke Test Checklist
- **"Coverage Matrix"** → understand what's implemented and what needs testing
- **"Integration Risk Map"** → identify high-risk integration points to test

### 2. Write Smoke Tests (Tier 1)

Create tests in `tests/e2e/epic_{epic_name}/`:

```
tests/e2e/epic_{epic_name}/
├── test_smoke_01_{scenario}.py   (or .ts, .js, etc.)
├── test_smoke_02_{scenario}.py
└── ...
```

For each "E2E Test Scenario" from the report:
- Write a test that exercises the full user flow
- Test the happy path first
- Use **real assertions** — verify actual output/behavior, not just "no error"
- No mocking — use real services/data

### 3. Write Integration Tests (Tier 2)

Create tests in `tests/integration/epic_{epic_name}/`:

```
tests/integration/epic_{epic_name}/
├── test_integration_{module_a}_{module_b}.py
└── ...
```

For each "Integration Test Point" from the report:
- Test the interface between two modules
- Verify data flows correctly across module boundaries
- Test error cases at integration points
- Use **real services** — no mocks

### 4. Test Quality Rules

Every test MUST:
- Have a descriptive name explaining what it tests
- Have at least one concrete assertion
- Be independent — not depend on other tests' execution order
- Clean up after itself (temporary files, test data, etc.)
- Match the project's existing test framework and patterns

Every test MUST NOT:
- Use mocks or stubs for core functionality
- Skip or disable any assertions
- Depend on specific timing or sleep delays
- Hard-code paths or environment-specific values

### 5. Commit Tests

After writing tests:
```bash
git add tests/e2e/epic_{epic_name}/ tests/integration/epic_{epic_name}/
git commit -m "Issue #{issue}: Write smoke + integration tests for epic {epic_name}"
```

### 6. Verify Tests Run

Run the tests to ensure they execute (they may fail — that's expected):
```bash
# Smoke tests
bash .claude/context/verify/epic-verify.sh {epic_name} --skip-performance
```

Report which tests pass and which fail. Failures are expected at this stage — the fix loop will handle them.
