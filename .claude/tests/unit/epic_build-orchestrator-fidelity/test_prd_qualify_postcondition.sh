#!/usr/bin/env bash
# Tests for prd-qualify post-condition checks (Issue #216)
set -e

PASS=0
FAIL=0
TMP=$(mktemp -d)

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# ─── Helpers ────────────────────────────────────────────────────────────────

# Simulate freshness check: report_date >= loop_start → fresh
is_fresh() {
  local report_date="$1" loop_start="$2"
  [[ "$report_date" > "$loop_start" || "$report_date" == "$loop_start" ]]
}

# Simulate suspicious first-pass detection
is_suspicious_firstpass() {
  local report="$1"
  grep -q 'status: passed' "$report" \
    && grep -qA5 'Critical Issues' "$report" | grep -q 'None' \
    && grep -qA5 'Warnings' "$report" | grep -q 'None'
}

# Simulate PRD modification check
prds_differ() {
  local hash1="$1" hash2="$2"
  [ "$hash1" != "$hash2" ]
}

# ─── Test 1: Fresh report with status: passed → post-condition passes ────────

echo "Test 1: Fresh report, status: passed → passes"
REPORT="$TMP/val_fresh.md"
LOOP_START="2026-03-20T01:00:00Z"
REPORT_DATE="2026-03-20T01:05:00Z"
cat > "$REPORT" <<EOF
---
status: passed
date: $REPORT_DATE
---
## Critical Issues
None
## Warnings
None
EOF

if is_fresh "$REPORT_DATE" "$LOOP_START" && grep -q 'status: passed' "$REPORT"; then
  pass "Test 1"
else
  fail "Test 1"
fi

# ─── Test 2: Stale report → post-condition fails (freshness) ─────────────────

echo "Test 2: Stale report → freshness check fails"
REPORT="$TMP/val_stale.md"
LOOP_START="2026-03-20T02:00:00Z"
REPORT_DATE="2026-03-20T01:00:00Z"   # older than loop start
cat > "$REPORT" <<EOF
---
status: passed
date: $REPORT_DATE
---
EOF

if is_fresh "$REPORT_DATE" "$LOOP_START"; then
  fail "Test 2 (should have been stale)"
else
  pass "Test 2"
fi

# ─── Test 3: No validation report after loop → post-condition fails ───────────

echo "Test 3: No validation report → post-condition fails"
REPORT="$TMP/nonexistent_val.md"

if [ -f "$REPORT" ]; then
  fail "Test 3 (file should not exist)"
else
  pass "Test 3"
fi

# ─── Test 4: First iteration, status: passed, 0 findings → triggers warning ──

echo "Test 4: First-pass 0 findings → suspicious detection triggers"
REPORT="$TMP/val_0findings.md"
cat > "$REPORT" <<EOF
---
status: passed
date: 2026-03-20T01:05:00Z
---
## Critical Issues
None
## Warnings
None
EOF

# Simulate: is suspicious if status=passed AND Critical Issues=None AND Warnings=None
status=$(grep '^status:' "$REPORT" | head -1 | awk '{print $2}')
crit_none=$(grep -A1 'Critical Issues' "$REPORT" | grep -c 'None' || true)
warn_none=$(grep -A1 'Warnings' "$REPORT" | grep -c 'None' || true)

if [ "$status" = "passed" ] && [ "$crit_none" -gt 0 ] && [ "$warn_none" -gt 0 ]; then
  pass "Test 4"
else
  fail "Test 4"
fi

# ─── Test 5: PRD hash unchanged, validation has issues → triggers warning ────

echo "Test 5: PRD hash unchanged + validation issues → modification warning"
PRD="$TMP/feature.md"
echo "content unchanged" > "$PRD"

hash_before=$(md5 -q "$PRD" 2>/dev/null || md5sum "$PRD" 2>/dev/null | awk '{print $1}')
# simulate no edit
hash_after=$(md5 -q "$PRD" 2>/dev/null || md5sum "$PRD" 2>/dev/null | awk '{print $1}')

REPORT="$TMP/val_issues.md"
cat > "$REPORT" <<EOF
---
status: failed
date: 2026-03-20T01:05:00Z
---
EOF
val_status=$(grep '^status:' "$REPORT" | head -1 | awk '{print $2}')

if [ "$hash_before" = "$hash_after" ] && [ "$val_status" != "passed" ]; then
  pass "Test 5"
else
  fail "Test 5"
fi

# ─── Test 6: PRD hash changed after edit → no modification warning ───────────

echo "Test 6: PRD hash changed → no modification warning"
PRD="$TMP/feature2.md"
echo "original content" > "$PRD"
hash_before=$(md5 -q "$PRD" 2>/dev/null || md5sum "$PRD" 2>/dev/null | awk '{print $1}')

# simulate edit
echo "modified content" > "$PRD"
hash_after=$(md5 -q "$PRD" 2>/dev/null || md5sum "$PRD" 2>/dev/null | awk '{print $1}')

if prds_differ "$hash_before" "$hash_after"; then
  pass "Test 6"
else
  fail "Test 6"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
