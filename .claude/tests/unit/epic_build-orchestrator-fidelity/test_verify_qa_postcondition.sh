#!/usr/bin/env bash
# Tests for epic-verify QA post-condition check logic
# Task #218: Epic-verify QA post-condition check

set -euo pipefail

PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# Helper: simulate the post-condition check logic
run_qa_check() {
  local report_file="$1"
  if [ -f "$report_file" ]; then
    if grep -q "## .*QA.*Results" "$report_file"; then
      echo "QA_PRESENT"
    else
      echo "QA_MISSING"
    fi
  else
    echo "REPORT_MISSING"
  fi
}

# Setup
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Running: test_verify_qa_postcondition.sh"
echo ""

# Test 1: Report with standard QA Agent Results header
echo "Test 1: Report with '## QA Agent Results' header"
cat > "$TMPDIR/report1.md" <<'EOF'
# Verify Report

## Summary
All checks passed.

## QA Agent Results
- Unit tests: PASS
- Integration tests: PASS
EOF
result=$(run_qa_check "$TMPDIR/report1.md")
[ "$result" = "QA_PRESENT" ] && pass "outputs QA_PRESENT for '## QA Agent Results'" || fail "expected QA_PRESENT, got: $result"

# Test 2: Report with Web QA Results header (variant)
echo "Test 2: Report with '## Web QA Results' header"
cat > "$TMPDIR/report2.md" <<'EOF'
# Verify Report

## Summary
All checks passed.

## Web QA Results
- Smoke tests: PASS
EOF
result=$(run_qa_check "$TMPDIR/report2.md")
[ "$result" = "QA_PRESENT" ] && pass "outputs QA_PRESENT for '## Web QA Results'" || fail "expected QA_PRESENT, got: $result"

# Test 3: Report with iOS QA Results header (variant)
echo "Test 3: Report with '## iOS QA Results' header"
cat > "$TMPDIR/report3.md" <<'EOF'
# Verify Report

## iOS QA Results
- UI tests: PASS
EOF
result=$(run_qa_check "$TMPDIR/report3.md")
[ "$result" = "QA_PRESENT" ] && pass "outputs QA_PRESENT for '## iOS QA Results'" || fail "expected QA_PRESENT, got: $result"

# Test 4: Report without any QA section
echo "Test 4: Report without QA section"
cat > "$TMPDIR/report4.md" <<'EOF'
# Verify Report

## Summary
Checks completed.

## Code Review Results
- Linting: PASS
EOF
result=$(run_qa_check "$TMPDIR/report4.md")
[ "$result" = "QA_MISSING" ] && pass "outputs QA_MISSING when no QA section" || fail "expected QA_MISSING, got: $result"

# Test 5: No report file exists
echo "Test 5: No report file"
result=$(run_qa_check "$TMPDIR/nonexistent-report.md")
[ "$result" = "REPORT_MISSING" ] && pass "outputs REPORT_MISSING when no report file" || fail "expected REPORT_MISSING, got: $result"

# Test 6: Empty report file
echo "Test 6: Empty report file"
> "$TMPDIR/report6.md"
result=$(run_qa_check "$TMPDIR/report6.md")
[ "$result" = "QA_MISSING" ] && pass "outputs QA_MISSING for empty report" || fail "expected QA_MISSING, got: $result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
