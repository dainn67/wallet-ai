#!/bin/bash
# E2E Tests: diff-detect.sh — screen name extraction + scenario filtering
# Tests heuristics and filter logic without requiring git or simulator
set -euo pipefail

PASS=0
FAIL=0

# Navigate to repo root (tests run from any directory)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected '$expected', got '$actual'"
    (( FAIL++ )) || true
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected to contain '$needle' in: $haystack"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if ! printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected NOT to contain '$needle' in: $haystack"
    (( FAIL++ )) || true
  fi
}

echo "=== Diff-Detect Script Tests ==="

# ---------------------------------------------------------------------------
# Test 1: Script exists and is executable
# ---------------------------------------------------------------------------
echo ""
echo "-- Prerequisite checks --"

SCRIPT="scripts/qa/diff-detect.sh"

if [ -f "$SCRIPT" ]; then
  echo "  ✅ $SCRIPT exists"
  (( PASS++ )) || true
else
  echo "  ❌ $SCRIPT not found"
  (( FAIL++ )) || true
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

if [ -x "$SCRIPT" ]; then
  echo "  ✅ $SCRIPT is executable"
  (( PASS++ )) || true
else
  echo "  ❌ $SCRIPT is not executable"
  (( FAIL++ )) || true
fi

# shellcheck passes (only info SC1091 is acceptable, not errors)
if shellcheck "$SCRIPT" 2>&1 | grep -qE '^In.*error'; then
  echo "  ❌ shellcheck found errors in $SCRIPT"
  (( FAIL++ )) || true
else
  echo "  ✅ shellcheck: no errors in $SCRIPT"
  (( PASS++ )) || true
fi

# ---------------------------------------------------------------------------
# Test 2: Screen name extraction heuristics (_extract_screen_name)
# ---------------------------------------------------------------------------
echo ""
echo "-- Screen name extraction heuristics --"

# Source the script functions without running in git context that might fail
# We test internal functions directly
source "$SCRIPT" 2>/dev/null || true

# QuizView.swift → QuizView (already a View)
result=$(_extract_screen_name "QuizView")
assert_eq "QuizView.swift → QuizView" "QuizView" "$result"

# QuizViewController.swift → QuizView (strip ViewController)
result=$(_extract_screen_name "QuizViewController")
assert_eq "QuizViewController.swift → QuizView" "QuizView" "$result"

# QuizController.swift → QuizView (strip Controller)
result=$(_extract_screen_name "QuizController")
assert_eq "QuizController.swift → QuizView" "QuizView" "$result"

# QuizVC.swift → QuizView (strip VC)
result=$(_extract_screen_name "QuizVC")
assert_eq "QuizVC.swift → QuizView" "QuizView" "$result"

# ContentView.swift → ContentView (already ends with View)
result=$(_extract_screen_name "ContentView")
assert_eq "ContentView.swift → ContentView" "ContentView" "$result"

# ---------------------------------------------------------------------------
# Test 3: Non-screen files should be skipped (_is_screen_file)
# ---------------------------------------------------------------------------
echo ""
echo "-- Non-screen file skip logic --"

# QuizModel.swift → skipped
result=$(_extract_screen_name "QuizModel")
assert_eq "QuizModel.swift → empty (skipped)" "" "$result"

# AppDelegate.swift → skipped
result=$(_extract_screen_name "AppDelegate")
assert_eq "AppDelegate.swift → empty (skipped)" "" "$result"

# SceneDelegate.swift → skipped
result=$(_extract_screen_name "SceneDelegate")
assert_eq "SceneDelegate.swift → empty (skipped)" "" "$result"

# QuizService.swift → skipped
result=$(_extract_screen_name "QuizService")
assert_eq "QuizService.swift → empty (skipped)" "" "$result"

# QuizManager.swift → skipped
result=$(_extract_screen_name "QuizManager")
assert_eq "QuizManager.swift → empty (skipped)" "" "$result"

# ---------------------------------------------------------------------------
# Test 4: filter_scenarios — filtering logic
# ---------------------------------------------------------------------------
echo ""
echo "-- filter_scenarios filtering logic --"

# Test: filter with QuizView → should return quiz-flow.md and accessibility-check.md
SCREENS_JSON='{"success":true,"error":null,"data":{"screens":["QuizView"],"source_files":["QuizView.swift"]}}'
FILTER_RESULT=$(filter_scenarios "$SCREENS_JSON")

assert_contains "filter QuizView → includes quiz-flow.md" "quiz-flow.md" "$FILTER_RESULT"
assert_contains "filter QuizView → includes accessibility-check.md" "accessibility-check.md" "$FILTER_RESULT"
assert_not_contains "filter QuizView → excludes settings-navigation.md" "settings-navigation.md" "$FILTER_RESULT"
assert_contains "filter QuizView → success:true" '"success":true' "$FILTER_RESULT"

# Test: filter with SettingsView → should return settings-navigation.md
SCREENS_JSON='{"success":true,"error":null,"data":{"screens":["SettingsView"],"source_files":["SettingsView.swift"]}}'
FILTER_RESULT=$(filter_scenarios "$SCREENS_JSON")

assert_contains "filter SettingsView → includes settings-navigation.md" "settings-navigation.md" "$FILTER_RESULT"
assert_not_contains "filter SettingsView → excludes quiz-flow.md" "quiz-flow.md" "$FILTER_RESULT"

# Test: filter with no matching screen → conservative fallback: returns all scenarios
SCREENS_JSON='{"success":true,"error":null,"data":{"screens":["NonExistentView"],"source_files":["NonExistent.swift"]}}'
FILTER_RESULT=$(filter_scenarios "$SCREENS_JSON")

assert_contains "no match → fallback:true" '"fallback":true' "$FILTER_RESULT"
assert_contains "no match → includes all scenarios (quiz-flow)" "quiz-flow.md" "$FILTER_RESULT"
assert_contains "no match → includes all scenarios (settings)" "settings-navigation.md" "$FILTER_RESULT"

# Test: filter with fallback key in input (no screen files changed) → returns all
SCREENS_JSON='{"success":true,"error":null,"data":{"screens":[],"source_files":[],"fallback":"no_screen_files_changed"}}'
FILTER_RESULT=$(filter_scenarios "$SCREENS_JSON")

assert_contains "fallback input → returns all (quiz-flow)" "quiz-flow.md" "$FILTER_RESULT"
assert_contains "fallback input → fallback:true in output" '"fallback":true' "$FILTER_RESULT"

# ---------------------------------------------------------------------------
# Test 5: filter_scenarios — multiple files → union of screens
# ---------------------------------------------------------------------------
echo ""
echo "-- Multiple changed files: union of screens --"

# QuizView + SettingsView → both quiz-flow.md and settings-navigation.md
SCREENS_JSON='{"success":true,"error":null,"data":{"screens":["QuizView","SettingsView"],"source_files":["QuizView.swift","SettingsViewController.swift"]}}'
FILTER_RESULT=$(filter_scenarios "$SCREENS_JSON")

assert_contains "union QuizView+SettingsView → quiz-flow.md" "quiz-flow.md" "$FILTER_RESULT"
assert_contains "union QuizView+SettingsView → settings-navigation.md" "settings-navigation.md" "$FILTER_RESULT"

# ---------------------------------------------------------------------------
# Test 6: detect_affected_screens with clean working tree (or no git)
# ---------------------------------------------------------------------------
echo ""
echo "-- detect_affected_screens edge cases --"

# Run detect_affected_screens — in a clean git repo this should return fallback
DETECT_RESULT=$(detect_affected_screens 2>/dev/null || echo '{"success":false,"error":"sourcing failed","data":null}')

assert_contains "detect_affected_screens → success:true" '"success":true' "$DETECT_RESULT"

# If clean tree, should have fallback key
if printf '%s' "$DETECT_RESULT" | grep -q '"fallback"'; then
  echo "  ✅ detect_affected_screens → fallback present (clean tree or no screens in diff)"
  (( PASS++ )) || true
else
  # Could also have screens if there ARE changes — just check it's valid JSON
  if printf '%s' "$DETECT_RESULT" | grep -q '"screens"'; then
    echo "  ✅ detect_affected_screens → screens key present (valid output)"
    (( PASS++ )) || true
  else
    echo "  ❌ detect_affected_screens → unexpected output: $DETECT_RESULT"
    (( FAIL++ )) || true
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
