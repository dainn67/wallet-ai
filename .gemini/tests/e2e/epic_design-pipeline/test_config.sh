#!/usr/bin/env bash
# Tests for config/lifecycle.json and config/model-tiers.json changes (Issue #121)
# Validates design_phase section and prd-design tier registration.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_ok() {
  local desc="$1" result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" = "true" ]; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "======================================="
echo " Tests: Config & Directory Structure"
echo "======================================="

# --- Test 1: lifecycle.json is valid JSON ---
echo ""
echo "Test 1: lifecycle.json validity"
jq_exit=$(jq . "$PROJECT_ROOT/config/lifecycle.json" >/dev/null 2>&1; echo $?)
assert_ok "config/lifecycle.json is valid JSON" "$([ "$jq_exit" = "0" ] && echo true || echo false)"

# --- Test 2: design_phase section exists with correct fields ---
echo ""
echo "Test 2: design_phase section"
enabled=$(jq '.design_phase.enabled' "$PROJECT_ROOT/config/lifecycle.json" 2>/dev/null)
auto_detect=$(jq '.design_phase.auto_detect_tools' "$PROJECT_ROOT/config/lifecycle.json" 2>/dev/null)
fallback=$(jq '.design_phase.fallback_to_text' "$PROJECT_ROOT/config/lifecycle.json" 2>/dev/null)
assert_ok "design_phase.enabled exists and is boolean" "$([ "$enabled" = "true" ] && echo true || echo false)"
assert_ok "design_phase.auto_detect_tools exists and is boolean" "$([ "$auto_detect" = "true" ] && echo true || echo false)"
assert_ok "design_phase.fallback_to_text exists and is boolean" "$([ "$fallback" = "true" ] && echo true || echo false)"

# --- Test 3: All existing sections still present ---
echo ""
echo "Test 3: No existing sections removed"
section_count=$(jq 'keys | length' "$PROJECT_ROOT/config/lifecycle.json" 2>/dev/null)
assert_ok "lifecycle.json has >= 8 sections (got $section_count)" "$([ "$section_count" -ge 8 ] && echo true || echo false)"
for section in verification context cost_control design_gate test_first semantic_review superpowers; do
  exists=$(jq "has(\"$section\")" "$PROJECT_ROOT/config/lifecycle.json" 2>/dev/null)
  assert_ok "section '$section' still present" "$([ "$exists" = "true" ] && echo true || echo false)"
done

# --- Test 4: model-tiers.json is valid JSON ---
echo ""
echo "Test 4: model-tiers.json validity"
jq_exit=$(jq . "$PROJECT_ROOT/config/model-tiers.json" >/dev/null 2>&1; echo $?)
assert_ok "config/model-tiers.json is valid JSON" "$([ "$jq_exit" = "0" ] && echo true || echo false)"

# --- Test 5: prd-design registered in heavy tier ---
echo ""
echo "Test 5: prd-design in heavy tier"
tier=$(jq -r '.commands["prd-design"]' "$PROJECT_ROOT/config/model-tiers.json" 2>/dev/null)
assert_ok "prd-design is in heavy tier" "$([ "$tier" = "heavy" ] && echo true || echo false)"

# --- Test 6: Existing tier assignments unchanged ---
echo ""
echo "Test 6: Existing tier assignments preserved"
for cmd in "prd-new:heavy" "prd-parse:heavy" "epic-decompose:heavy" "status:medium" "help:medium"; do
  name="${cmd%%:*}"
  expected="${cmd##*:}"
  actual=$(jq -r ".commands[\"$name\"]" "$PROJECT_ROOT/config/model-tiers.json" 2>/dev/null)
  assert_ok "$name still in $expected tier" "$([ "$actual" = "$expected" ] && echo true || echo false)"
done

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
