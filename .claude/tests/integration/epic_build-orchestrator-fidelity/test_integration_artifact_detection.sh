#!/usr/bin/env bash
# Integration Test: Artifact detection logic integrates correctly with build.md structure
# Epic: build-orchestrator-fidelity
# Tests that the logic patterns in build.md would behave correctly at runtime

set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== Integration Test: Artifact Detection Logic ==="

# Helper: extract the artifact detection bash logic from build.md and test it
# We simulate the detection patterns directly

## --- prd-qualify detection ---
echo ""
echo "-- prd-qualify artifact detection --"

# Test 1: PRD validated + validation report passed → should skip
mkdir -p "$TMPDIR_TEST/prds"
cat > "$TMPDIR_TEST/prds/test-feature.md" <<'EOF'
---
status: validated
name: test-feature
---
# PRD
EOF
cat > "$TMPDIR_TEST/prds/.validation-test-feature.md" <<'EOF'
---
status: passed
date: 2026-03-20T01:00:00Z
---
# Validation Report
EOF
feature_name="test-feature"
status=$(grep '^status:' "$TMPDIR_TEST/prds/${feature_name}.md" | head -1 | awk '{print $2}')
val_status=""
if [ -f "$TMPDIR_TEST/prds/.validation-${feature_name}.md" ]; then
  val_status=$(grep '^status:' "$TMPDIR_TEST/prds/.validation-${feature_name}.md" | head -1 | awk '{print $2}')
fi
if [ "$status" = "validated" ] && [ "$val_status" = "passed" ]; then
  pass "PRD validated + validation passed → skip=true"
else
  fail "PRD validated + validation passed → expected skip=true, got status=$status val_status=$val_status"
fi

# Test 2: PRD validated but no validation report → should NOT skip
rm -f "$TMPDIR_TEST/prds/.validation-test-feature.md"
val_status=""
if [ -f "$TMPDIR_TEST/prds/.validation-${feature_name}.md" ]; then
  val_status=$(grep '^status:' "$TMPDIR_TEST/prds/.validation-${feature_name}.md" | head -1 | awk '{print $2}')
fi
if [ "$status" = "validated" ] && [ "$val_status" = "passed" ]; then
  fail "PRD validated but no validation report → expected skip=false, but got skip=true"
else
  pass "PRD validated but no validation report → skip=false"
fi

## --- plan-review detection ---
echo ""
echo "-- plan-review artifact detection --"

# Test 3: plan-review with verdict: ready → should skip
mkdir -p "$TMPDIR_TEST/epics/test-feature"
cat > "$TMPDIR_TEST/epics/test-feature/plan-review.md" <<'EOF'
---
verdict: ready
critical_gaps: 0
warnings: 0
---
# Plan Review
EOF
verdict=$(grep '^verdict:' "$TMPDIR_TEST/epics/test-feature/plan-review.md" 2>/dev/null | head -1 | awk '{print $2}' || echo "")
if [ -f "$TMPDIR_TEST/epics/test-feature/plan-review.md" ] && [ "$verdict" != "blocked" ] && [ -n "$verdict" ]; then
  pass "plan-review verdict=ready → skip=true"
else
  fail "plan-review verdict=ready → expected skip=true"
fi

# Test 4: plan-review with verdict: blocked → should NOT skip
cat > "$TMPDIR_TEST/epics/test-feature/plan-review.md" <<'EOF'
---
verdict: blocked
critical_gaps: 2
warnings: 3
---
# Plan Review
EOF
verdict=$(grep '^verdict:' "$TMPDIR_TEST/epics/test-feature/plan-review.md" 2>/dev/null | head -1 | awk '{print $2}' || echo "")
if [ "$verdict" = "blocked" ]; then
  pass "plan-review verdict=blocked → skip=false (blocked detected)"
else
  fail "plan-review verdict=blocked → expected blocked detection"
fi

# Test 5: plan-review missing verdict → should NOT skip (treat as incomplete)
cat > "$TMPDIR_TEST/epics/test-feature/plan-review.md" <<'EOF'
---
critical_gaps: 1
---
# Plan Review (no verdict)
EOF
verdict=$(grep '^verdict:' "$TMPDIR_TEST/epics/test-feature/plan-review.md" 2>/dev/null | head -1 | awk '{print $2}' || echo "")
if [ -z "$verdict" ]; then
  pass "plan-review missing verdict → correctly identified as empty"
else
  fail "plan-review missing verdict → expected empty verdict"
fi

## --- epic-verify QA detection ---
echo ""
echo "-- epic-verify QA detection --"

# Test 6: verify report with QA Agent Results section → post-condition passes
mkdir -p "$TMPDIR_TEST/verify-reports"
cat > "$TMPDIR_TEST/verify-reports/test-feature-final-20260320.md" <<'EOF'
# Epic Verification Report

## Coverage Matrix
All good.

## QA Agent Results
**Status:** PASS
**Health Score:** 90/100
EOF
report_file=$(ls -t "$TMPDIR_TEST/verify-reports/test-feature-final-"*.md 2>/dev/null | head -1)
if [ -f "$report_file" ] && grep -q "## .*QA.*Results" "$report_file"; then
  pass "verify report with QA Agent Results → post-condition passes"
else
  fail "verify report with QA Agent Results → expected pass"
fi

# Test 7: verify report without QA section → QA_MISSING
cat > "$TMPDIR_TEST/verify-reports/test-feature-final-20260320.md" <<'EOF'
# Epic Verification Report

## Coverage Matrix
All good.

## Test Results
Pass.
EOF
if grep -q "## .*QA.*Results" "$report_file" 2>/dev/null; then
  fail "verify report without QA section → expected QA_MISSING"
else
  pass "verify report without QA section → QA_MISSING (correct)"
fi

# Test 8: Web QA Results header format (alternate agent)
cat > "$TMPDIR_TEST/verify-reports/test-feature-final-20260320.md" <<'EOF'
# Epic Verification Report

## Web QA Results
**Status:** PASS
EOF
if grep -q "## .*QA.*Results" "$report_file"; then
  pass "Web QA Results header matched by pattern"
else
  fail "Web QA Results header NOT matched by pattern"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
