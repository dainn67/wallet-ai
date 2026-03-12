#!/bin/bash
# Epic Integration Verification — Phase B
# 4-Tier test runner: Smoke → Integration → Regression → Performance
#
# Usage: bash .gemini/context/verify/epic-verify.sh <epic-name> [--skip-performance]
# Exit:  0=EPIC_VERIFY_PASS, 1=EPIC_VERIFY_FAIL, 2=EPIC_VERIFY_PARTIAL

set -o pipefail

EPIC_NAME="${1:?Usage: epic-verify.sh <epic-name> [--skip-performance]}"
SKIP_PERF=""
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-performance) SKIP_PERF=1 ;;
  esac
  shift
done

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"

FAIL=0
PARTIAL=0

# ── Read config from epic-verify.json ──
CONFIG_FILE=".gemini/config/epic-verify.json"
if [ -f "$CONFIG_FILE" ]; then
  SMOKE_REQUIRED=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['smoke']['required'])" 2>/dev/null || echo "True")
  SMOKE_BLOCKING=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['smoke']['blocking'])" 2>/dev/null || echo "True")
  INTEG_REQUIRED=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['integration']['required'])" 2>/dev/null || echo "True")
  INTEG_BLOCKING=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['integration']['blocking'])" 2>/dev/null || echo "True")
  REGR_REQUIRED=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['regression']['required'])" 2>/dev/null || echo "True")
  REGR_BLOCKING=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['regression']['blocking'])" 2>/dev/null || echo "False")
  PERF_REQUIRED=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['performance']['required'])" 2>/dev/null || echo "False")
  PERF_BLOCKING=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b']['test_tiers']['performance']['blocking'])" 2>/dev/null || echo "False")
  SKIP_PERF_DEFAULT=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['phase_b'].get('skip_performance_by_default', False))" 2>/dev/null || echo "False")
  # Apply default skip if no explicit flag
  if [ -z "$SKIP_PERF" ] && [ "$SKIP_PERF_DEFAULT" = "True" ]; then
    SKIP_PERF=1
  fi
else
  # Defaults matching PRD spec
  SMOKE_REQUIRED="True"; SMOKE_BLOCKING="True"
  INTEG_REQUIRED="True"; INTEG_BLOCKING="True"
  REGR_REQUIRED="True"; REGR_BLOCKING="False"
  PERF_REQUIRED="False"; PERF_BLOCKING="False"
fi

# ── Detect test framework for Tier 3 ──
detect_test_command() {
  local detect_script=".gemini/scripts/testing/detect-framework.sh"
  if [ -f "$detect_script" ]; then
    local result
    result=$(bash "$detect_script" 2>/dev/null)
    local cmd
    cmd=$(echo "$result" | grep "^test_command:" | sed 's/^test_command: //')
    if [ -n "$cmd" ]; then
      echo "$cmd"
      return 0
    fi
  fi

  # Fallback auto-detect
  if [ -f "pubspec.yaml" ]; then
    if [ -f ".fvmrc" ] || [ -d ".fvm" ]; then
      echo "fvm flutter test"
    else
      echo "flutter test"
    fi
  elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -d "tests" ]; then
    echo "python3 -m pytest tests/ -v --tb=short"
  elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    echo "npm test"
  elif [ -f "Package.swift" ]; then
    echo "swift test"
  elif [ -f "Cargo.toml" ]; then
    echo "cargo test"
  elif [ -f "go.mod" ]; then
    echo "go test ./..."
  else
    echo ""
  fi
}

# ── Run a test tier ──
# Args: $1=tier_name $2=test_dir $3=required $4=blocking
run_tier() {
  local tier_name="$1"
  local test_dir="$2"
  local required="$3"
  local blocking="$4"
  local tier_exit=0

  if [ ! -d "$test_dir" ]; then
    if [ "$required" = "True" ]; then
      echo "⚠️  $tier_name: Test directory not found at $test_dir — skipping"
    else
      echo "ℹ️  $tier_name: No tests at $test_dir"
    fi
    return 0
  fi

  # Detect runner for this directory
  local cmd
  if [ -f "pubspec.yaml" ]; then
    if [ -f ".fvmrc" ] || [ -d ".fvm" ]; then
      cmd="fvm flutter test $test_dir"
    else
      cmd="flutter test $test_dir"
    fi
  elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "conftest.py" ]; then
    cmd="python3 -m pytest $test_dir -v --tb=short"
  elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    cmd="npx jest $test_dir --verbose"
  elif [ -f "Package.swift" ]; then
    cmd="swift test --filter $(basename "$test_dir")"
  elif [ -f "Cargo.toml" ]; then
    cmd="cargo test"
  elif [ -f "go.mod" ]; then
    cmd="go test ./$test_dir/..."
  else
    cmd="python3 -m pytest $test_dir -v --tb=short"
  fi

  eval "$cmd" 2>&1
  tier_exit=$?

  if [ $tier_exit -eq 0 ]; then
    echo "✅ $tier_name: PASS"
  else
    if [ "$blocking" = "True" ]; then
      echo "❌ $tier_name: FAIL (blocking)"
      FAIL=1
    else
      echo "⚠️  $tier_name: FAIL (non-blocking)"
      PARTIAL=1
    fi
  fi

  return $tier_exit
}

# ══════════════════════════════════════════
echo "══════════════════════════════════════════"
echo "  EPIC VERIFICATION — PHASE B"
echo "  Epic: $EPIC_NAME"
echo "══════════════════════════════════════════"

# ── Tầng 1: Smoke Tests ──
echo ""
echo "┌─────────────────────────────────────┐"
echo "│  TẦNG 1: SMOKE TESTS               │"
echo "└─────────────────────────────────────┘"

SMOKE_DIR="tests/e2e/epic_${EPIC_NAME}"
run_tier "TẦNG 1" "$SMOKE_DIR" "$SMOKE_REQUIRED" "$SMOKE_BLOCKING"

# If Tier 1 is blocking and failed, stop early
if [ $FAIL -ne 0 ] && [ "$SMOKE_BLOCKING" = "True" ]; then
  echo ""
  echo "══════════════════════════════════════════"
  echo "EPIC_VERIFY_FAIL"
  exit 1
fi

# ── Tầng 2: Integration Tests ──
echo ""
echo "┌─────────────────────────────────────────┐"
echo "│  TẦNG 2: INTEGRATION TESTS              │"
echo "└─────────────────────────────────────────┘"

INTEG_DIR="tests/integration/epic_${EPIC_NAME}"
run_tier "TẦNG 2" "$INTEG_DIR" "$INTEG_REQUIRED" "$INTEG_BLOCKING"

# If Tier 2 is blocking and failed, stop early
if [ $FAIL -ne 0 ] && [ "$INTEG_BLOCKING" = "True" ]; then
  echo ""
  echo "══════════════════════════════════════════"
  echo "EPIC_VERIFY_FAIL"
  exit 1
fi

# ── Tầng 3: Regression Tests ──
echo ""
echo "┌──────────────────────────────────────────┐"
echo "│  TẦNG 3: REGRESSION TESTS                │"
echo "└──────────────────────────────────────────┘"

TEST_CMD=$(detect_test_command)
if [ -n "$TEST_CMD" ]; then
  eval "$TEST_CMD" 2>&1
  tier3_exit=$?
  if [ $tier3_exit -eq 0 ]; then
    echo "✅ TẦNG 3: PASS"
  else
    if [ "$REGR_BLOCKING" = "True" ]; then
      echo "❌ TẦNG 3: FAIL (blocking)"
      FAIL=1
    else
      echo "⚠️  TẦNG 3: FAIL (non-blocking)"
      PARTIAL=1
    fi
  fi
else
  echo "⚠️  TẦNG 3: No test runner detected — skipping"
fi

# ── Tầng 4: Performance Tests ──
echo ""
echo "┌──────────────────────────────────────────┐"
echo "│  TẦNG 4: PERFORMANCE TESTS               │"
echo "└──────────────────────────────────────────┘"

if [ -n "$SKIP_PERF" ]; then
  echo "⏭️  Skipped (--skip-performance)"
else
  PERF_DIR="tests/performance/epic_${EPIC_NAME}"
  run_tier "TẦNG 4" "$PERF_DIR" "$PERF_REQUIRED" "$PERF_BLOCKING"
fi

# ── Final Result ──
echo ""
echo "══════════════════════════════════════════"
if [ $FAIL -ne 0 ]; then
  echo "EPIC_VERIFY_FAIL"
  exit 1
elif [ $PARTIAL -ne 0 ]; then
  echo "EPIC_VERIFY_PARTIAL"
  exit 2
else
  echo "EPIC_VERIFY_PASS"
  exit 0
fi
