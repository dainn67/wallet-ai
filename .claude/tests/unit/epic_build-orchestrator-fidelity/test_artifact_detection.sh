#!/usr/bin/env bash
# Test: Enhanced artifact detection quality checks for build.md Step 1
# Tests verify the quality-aware skip logic described in task 215

set -euo pipefail

PASS=0
FAIL=0
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Helper: assert condition
assert() {
  local desc="$1"
  local result="$2"  # "true" or "false"
  local expected="$3"
  if [ "$result" = "$expected" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected=$expected got=$result)"
    FAIL=$((FAIL + 1))
  fi
}

# Helper: check prd-qualify skip condition
# Returns "true" if step should be skipped, "false" otherwise
check_prd_qualify() {
  local feature="$1"
  local prd_dir="$TMPDIR/prds"
  local prd_file="$prd_dir/${feature}.md"
  local val_file="$prd_dir/.validation-${feature}.md"

  if [ ! -f "$prd_file" ]; then echo "false"; return; fi

  local status
  status=$(grep '^status:' "$prd_file" | head -1 | awk '{print $2}')
  local val_status=""
  if [ -f "$val_file" ]; then
    val_status=$(grep '^status:' "$val_file" | head -1 | awk '{print $2}')
  fi

  if [ "$status" = "validated" ] && [ "$val_status" = "passed" ]; then
    echo "true"
  else
    echo "false"
  fi
}

# Helper: check plan-review skip condition
check_plan_review() {
  local feature="$1"
  local epic_dir="$TMPDIR/epics/${feature}"
  local pr_file="$epic_dir/plan-review.md"

  if [ ! -f "$pr_file" ]; then echo "false"; return; fi

  local verdict
  verdict=$(grep '^verdict:' "$pr_file" | head -1 | awk '{print $2}')

  if [ -z "$verdict" ] || [ "$verdict" = "blocked" ]; then
    echo "false"
  else
    echo "true"
  fi
}

# Helper: check epic-verify skip condition
check_epic_verify() {
  local feature="$1"
  local epic_dir="$TMPDIR/epics/${feature}"
  local report="$epic_dir/verify-report.md"

  if [ ! -f "$report" ]; then echo "false"; return; fi

  if grep -qE "^## .*QA.*Results" "$report"; then
    echo "true"
  else
    echo "false"
  fi
}

# ─── prd-qualify tests ───────────────────────────────────────────────────────
echo ""
echo "== prd-qualify detection =="

mkdir -p "$TMPDIR/prds"

# Test 1: PRD validated + validation report passed → skip
cat > "$TMPDIR/prds/feat-a.md" << 'EOF'
---
status: validated
---
EOF
cat > "$TMPDIR/prds/.validation-feat-a.md" << 'EOF'
---
status: passed
---
EOF
assert "PRD validated + validation report passed → skip=true" "$(check_prd_qualify feat-a)" "true"

# Test 2: PRD validated but no validation report → do NOT skip
cat > "$TMPDIR/prds/feat-b.md" << 'EOF'
---
status: validated
---
EOF
assert "PRD validated but no validation report → skip=false" "$(check_prd_qualify feat-b)" "false"

# Test 3: PRD status backlog → do NOT skip
cat > "$TMPDIR/prds/feat-c.md" << 'EOF'
---
status: backlog
---
EOF
assert "PRD status=backlog → skip=false" "$(check_prd_qualify feat-c)" "false"

# Test 4: PRD validated + validation report not-passed → do NOT skip
cat > "$TMPDIR/prds/feat-d.md" << 'EOF'
---
status: validated
---
EOF
cat > "$TMPDIR/prds/.validation-feat-d.md" << 'EOF'
---
status: failed
---
EOF
assert "PRD validated + validation status=failed → skip=false" "$(check_prd_qualify feat-d)" "false"

# ─── plan-review tests ───────────────────────────────────────────────────────
echo ""
echo "== plan-review detection =="

mkdir -p "$TMPDIR/epics/feat-e" "$TMPDIR/epics/feat-f" "$TMPDIR/epics/feat-g"

# Test 5: plan-review.md with verdict: ready → skip
cat > "$TMPDIR/epics/feat-e/plan-review.md" << 'EOF'
---
verdict: ready
---
EOF
assert "plan-review verdict=ready → skip=true" "$(check_plan_review feat-e)" "true"

# Test 6: plan-review.md with verdict: blocked → do NOT skip
cat > "$TMPDIR/epics/feat-f/plan-review.md" << 'EOF'
---
verdict: blocked
---
EOF
assert "plan-review verdict=blocked → skip=false" "$(check_plan_review feat-f)" "false"

# Test 7: plan-review.md without verdict field → do NOT skip
cat > "$TMPDIR/epics/feat-g/plan-review.md" << 'EOF'
---
name: test
---
EOF
assert "plan-review missing verdict field → skip=false" "$(check_plan_review feat-g)" "false"

# Test 8: plan-review.md does not exist → do NOT skip
assert "plan-review file missing → skip=false" "$(check_plan_review feat-nofile)" "false"

# ─── epic-verify tests ───────────────────────────────────────────────────────
echo ""
echo "== epic-verify detection =="

mkdir -p "$TMPDIR/epics/feat-h" "$TMPDIR/epics/feat-i"

# Test 9: verify-report.md with QA section → skip
cat > "$TMPDIR/epics/feat-h/verify-report.md" << 'EOF'
# Verify Report

## Summary

## QA Agent Results

All checks passed.
EOF
assert "verify-report has QA Agent Results section → skip=true" "$(check_epic_verify feat-h)" "true"

# Test 10: verify-report.md without QA section → do NOT skip
cat > "$TMPDIR/epics/feat-i/verify-report.md" << 'EOF'
# Verify Report

## Summary

No QA run yet.
EOF
assert "verify-report missing QA section → skip=false" "$(check_epic_verify feat-i)" "false"

# Test 11: verify-report.md does not exist → do NOT skip
assert "verify-report file missing → skip=false" "$(check_epic_verify feat-nofile)" "false"

# ─── Results ─────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
