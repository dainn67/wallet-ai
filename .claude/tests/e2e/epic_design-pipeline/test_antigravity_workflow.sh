#!/usr/bin/env bash
# Tests for Issue #125: Antigravity Sync & Documentation
# Verifies: workflow file, sync config coverage, README mentions

set -euo pipefail
PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  if eval "$2"; then
    PASS=$((PASS + 1))
    echo "  PASS: $1"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1"
  fi
}

echo "=== Test: Antigravity Workflow for prd-design ==="

# Test 1: Workflow file exists
assert "Workflow file exists" \
  "test -f antigravity/workflows/pm-prd-design.md"

# Test 2: Workflow has valid content (>10 lines)
assert "Workflow has valid content (>10 lines)" \
  '[ "$(wc -l < antigravity/workflows/pm-prd-design.md)" -gt 10 ]'

# Test 3: Workflow contains "design" references
assert "Workflow references design" \
  "grep -qi 'design' antigravity/workflows/pm-prd-design.md"

# Test 4: Workflow contains prd-design usage
assert "Workflow has prd-design usage" \
  "grep -q 'prd-design' antigravity/workflows/pm-prd-design.md"

# Test 5: Workflow has frontmatter with name field
assert "Workflow has name frontmatter" \
  "grep -q 'name: pm-prd-design' antigravity/workflows/pm-prd-design.md"

# Test 6: Workflow has description frontmatter
assert "Workflow has description frontmatter" \
  "grep -q 'description:' antigravity/workflows/pm-prd-design.md"

# Test 7: Workflow does NOT have allowed-tools (antigravity format)
assert "Workflow omits allowed-tools (antigravity format)" \
  "! grep -q '^allowed-tools:' antigravity/workflows/pm-prd-design.md"

# Test 8: Workflow does NOT have model field (antigravity format)
assert "Workflow omits model field (antigravity format)" \
  "! grep -q '^model:' antigravity/workflows/pm-prd-design.md"

# Test 9: Sync config covers commands/pm directory
assert "Sync config maps commands/pm to workflows" \
  "grep -q '\"source\": \"commands/pm\"' config/antigravity-sync.json"

# Test 10: README mentions prd-design
assert "README mentions prd-design" \
  "grep -qi 'prd-design' README.md"

# Test 11: README mentions design pipeline
assert "README mentions design pipeline" \
  "grep -qi 'design pipeline' README.md"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
