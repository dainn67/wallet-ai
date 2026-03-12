#!/usr/bin/env bash
# ccpm-verification: semantic-review.sh
#
# Displays the semantic review checklist for Gemini to follow.
# Reads from .gemini/prompts/task-semantic-review.md if available.
# Falls back to built-in checklist if file is missing.
# Advisory only — exits 0 always.

set -uo pipefail

REVIEW_TEMPLATE=".gemini/prompts/task-semantic-review.md"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM VERIFICATION — SEMANTIC REVIEW"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ -f "$REVIEW_TEMPLATE" ]; then
  echo "Checklist from: $REVIEW_TEMPLATE"
  echo ""
  cat "$REVIEW_TEMPLATE" 2>/dev/null || {
    echo "⚠️  Could not read $REVIEW_TEMPLATE — using built-in checklist."
    echo ""
    print_builtin_checklist
  }
else
  echo "⚠️  $REVIEW_TEMPLATE not found — using built-in checklist."
  echo ""

  cat <<'CHECKLIST'
## Semantic Review Checklist

### Correctness
- [ ] Implementation matches the acceptance criteria in the design file
- [ ] Edge cases are handled (empty input, null values, boundary conditions)
- [ ] No off-by-one errors in loops or array access
- [ ] Logic matches the intended behavior, not just the happy path

### Error Handling
- [ ] Errors are caught and handled at appropriate levels
- [ ] Error messages are clear and actionable
- [ ] No silent failures (errors are logged or surfaced)
- [ ] Resources are cleaned up on error paths (files, connections, etc.)

### Tests
- [ ] Tests cover the acceptance criteria
- [ ] Tests cover at least one failure/edge case
- [ ] Tests are deterministic (no random sleeps, flaky network calls)
- [ ] Tests clean up after themselves

### Code Quality
- [ ] No dead code or commented-out blocks left in
- [ ] No debug print statements or temporary logging
- [ ] Variable and function names are clear and consistent
- [ ] No duplication that should be extracted

### Design Traceability
- [ ] Implementation matches the approach described in the design file
- [ ] Any deviations from the design are documented
- [ ] Files changed match the "Files to Change" section of the design

### Documentation
- [ ] Public interfaces (functions, classes, APIs) have doc comments if needed
- [ ] Any non-obvious logic has an inline comment explaining "why"
- [ ] README or usage docs updated if behavior changed externally

---
Review each item. If any item is NOT satisfied, address it before closing the task.
CHECKLIST
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Review each checklist item before marking task done."
echo "═══════════════════════════════════════════════════════"
echo ""

exit 0
