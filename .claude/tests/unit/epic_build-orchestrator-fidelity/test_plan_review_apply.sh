#!/usr/bin/env bash
# Tests for Plan-review Apply mechanism (Task #217)
# Tests the logic documented in commands/pm/build.md "Special: Plan-review Apply"

PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# ── Helpers ──────────────────────────────────────────────────────────────────

# Simulates verdict extraction logic from build.md
extract_verdict() {
  local review_file="$1"
  if [ -f "$review_file" ]; then
    verdict=$(grep '^verdict:' "$review_file" | head -1 | awk '{print $2}')
    critical=$(grep '^critical_gaps:' "$review_file" | head -1 | awk '{print $2}')
    warnings=$(grep '^warnings:' "$review_file" | head -1 | awk '{print $2}')
  else
    verdict="skip"
    critical=0
    warnings=0
  fi
  echo "verdict=$verdict critical=${critical:-0} warnings=${warnings:-0}"
}

# Simulates the apply-decision logic
apply_decision() {
  local verdict="$1"
  local critical="${2:-0}"
  local warnings="${3:-0}"

  # Missing verdict → default to ready-with-warnings (fail-safe)
  if [ -z "$verdict" ] || [ "$verdict" = "" ]; then
    echo "apply-with-warnings"
    return
  fi
  if [ "$verdict" = "skip" ]; then
    echo "skip-no-file"
    return
  fi
  if [ "$verdict" = "blocked" ]; then
    echo "blocked"
    return
  fi
  if [ "$verdict" = "ready" ] && [ "${critical:-0}" = "0" ] && [ "${warnings:-0}" = "0" ]; then
    echo "skip-clean"
    return
  fi
  # ready-with-warnings OR warnings > 0
  echo "apply-with-warnings"
}

# ── Setup ────────────────────────────────────────────────────────────────────

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# ── Test 1: ready with 0 gaps, 0 warnings → skip apply ──────────────────────

echo ""
echo "Test 1: verdict=ready, 0 gaps, 0 warnings → skip apply"

cat > "$TMP/plan-review-clean.md" <<'EOF'
---
verdict: ready
critical_gaps: 0
warnings: 0
---
# Plan Review
All good.
EOF

eval "$(extract_verdict "$TMP/plan-review-clean.md")"
decision=$(apply_decision "$verdict" "$critical" "$warnings")

if [ "$decision" = "skip-clean" ]; then
  pass "skip-clean decision made"
else
  fail "Expected skip-clean, got: $decision"
fi

# Verify output would say "skipping apply"
if echo "$decision" | grep -q "skip"; then
  pass "Output contains skip indicator"
else
  fail "Output should contain skip indicator"
fi

# ── Test 2: verdict=blocked → blocked decision ───────────────────────────────

echo ""
echo "Test 2: verdict=blocked → failure menu output"

cat > "$TMP/plan-review-blocked.md" <<'EOF'
---
verdict: blocked
critical_gaps: 2
warnings: 1
---
# Plan Review
Critical: missing auth design
Critical: no rollback plan
EOF

eval "$(extract_verdict "$TMP/plan-review-blocked.md")"
decision=$(apply_decision "$verdict" "$critical" "$warnings")

if [ "$decision" = "blocked" ]; then
  pass "blocked decision made"
else
  fail "Expected blocked, got: $decision"
fi

# Verify BLOCKED text would appear in output
if [ "$verdict" = "blocked" ]; then
  pass "verdict=blocked detected correctly"
else
  fail "verdict should be 'blocked', got: $verdict"
fi

# ── Test 3: verdict=ready-with-warnings → triggers apply ─────────────────────

echo ""
echo "Test 3: verdict=ready-with-warnings → apply phase triggered"

cat > "$TMP/plan-review-warnings.md" <<'EOF'
---
verdict: ready-with-warnings
critical_gaps: 0
warnings: 3
---
# Plan Review
Warning: consider adding retry logic
Warning: missing timeout config
Warning: no rate limit handling
EOF

eval "$(extract_verdict "$TMP/plan-review-warnings.md")"
decision=$(apply_decision "$verdict" "$critical" "$warnings")

if [ "$decision" = "apply-with-warnings" ]; then
  pass "apply-with-warnings decision made"
else
  fail "Expected apply-with-warnings, got: $decision"
fi

if [ "$warnings" = "3" ]; then
  pass "warning count extracted correctly"
else
  fail "Expected warnings=3, got: $warnings"
fi

# ── Test 4: no verdict field → default to ready-with-warnings ────────────────

echo ""
echo "Test 4: no verdict field → default to ready-with-warnings"

cat > "$TMP/plan-review-no-verdict.md" <<'EOF'
---
critical_gaps: 0
warnings: 1
---
# Plan Review
No verdict field here.
EOF

eval "$(extract_verdict "$TMP/plan-review-no-verdict.md")"
# verdict will be empty string
decision=$(apply_decision "$verdict" "$critical" "$warnings")

if [ "$decision" = "apply-with-warnings" ]; then
  pass "missing verdict defaults to apply-with-warnings (fail-safe)"
else
  fail "Expected apply-with-warnings for missing verdict, got: $decision"
fi

# ── Test 5: plan-review.md doesn't exist → skip silently ─────────────────────

echo ""
echo "Test 5: plan-review.md doesn't exist → skip apply silently"

eval "$(extract_verdict "$TMP/nonexistent-plan-review.md")"
decision=$(apply_decision "$verdict" "$critical" "$warnings")

if [ "$decision" = "skip-no-file" ]; then
  pass "no-file case → skip silently"
else
  fail "Expected skip-no-file, got: $decision"
fi

# ── Test 6: epic hash unchanged after apply → warning ────────────────────────

echo ""
echo "Test 6: epic hash unchanged after apply → warn user"

cat > "$TMP/epic.md" <<'EOF'
---
name: test-feature
---
# Epic: test-feature
No changes here.
EOF

# Compute hash before and after (same content = same hash)
hash_before=$(md5 -q "$TMP/epic.md" 2>/dev/null || md5sum "$TMP/epic.md" 2>/dev/null | awk '{print $1}')
# Simulate apply that doesn't change anything
hash_after=$(md5 -q "$TMP/epic.md" 2>/dev/null || md5sum "$TMP/epic.md" 2>/dev/null | awk '{print $1}')

if [ "$hash_before" = "$hash_after" ]; then
  pass "hash comparison detects unchanged epic (would warn user)"
else
  fail "hash comparison should detect unchanged epic"
fi

# Simulate a real change
echo "# Additional content" >> "$TMP/epic.md"
hash_modified=$(md5 -q "$TMP/epic.md" 2>/dev/null || md5sum "$TMP/epic.md" 2>/dev/null | awk '{print $1}')

if [ "$hash_before" != "$hash_modified" ]; then
  pass "hash comparison detects changed epic (would confirm apply succeeded)"
else
  fail "hash comparison should detect modified epic"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
