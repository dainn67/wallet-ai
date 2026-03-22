#!/bin/bash
# Integration Tests: Web QA Platform — Verify Flow
# Tests: detect-agents works for web projects, not for non-web, both for mixed
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

DETECT_SCRIPT="$REPO_ROOT/scripts/qa/detect-agents.sh"
REGISTRY="$REPO_ROOT/config/qa-agents.json"

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
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  ❌ $desc: should NOT contain '$needle'"
    (( FAIL++ )) || true
  else
    echo "  ✅ $desc"
    (( PASS++ )) || true
  fi
}

assert_empty() {
  local desc="$1" val="$2"
  if [ -z "$val" ]; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected empty, got: $val"
    (( FAIL++ )) || true
  fi
}

# Helper: create a temp git repo with qa-agents.json
# Args: $1=config_json, $2=optional file to create (e.g. "package.json"), $3=optional content
make_git_project() {
  local config_json="$1"
  local extra_file="${2:-}"
  local extra_content="${3:-{}}"
  local d
  d=$(mktemp -d)
  git init "$d" -q
  mkdir -p "$d/.claude/config"
  printf '%s' "$config_json" > "$d/.claude/config/qa-agents.json"
  if [ -n "$extra_file" ]; then
    printf '%s' "$extra_content" > "$d/$extra_file"
  fi
  echo "$d"
}

echo "=== Web QA Platform Verify Flow Integration Tests ==="

# Prerequisites
echo ""
echo "-- Prerequisites --"
if [ -f "$DETECT_SCRIPT" ]; then
  echo "  ✅ scripts/qa/detect-agents.sh exists"
  (( PASS++ )) || true
else
  echo "  ❌ scripts/qa/detect-agents.sh not found"
  (( FAIL++ )) || true
  echo ""; echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

REGISTRY_JSON=$(cat "$REGISTRY")

# Test 1: Web detection — Next.js project (package.json with next dependency)
# detect-web.sh is the detect_command for web-qa-agent
# In a temp project without detect-web.sh available we test the glob match only
echo ""
echo "-- Web detection (package.json present, no detect_command) --"
# Use registry without detect_command to test glob-only match
WEB_ONLY_JSON='{"agents":[{"name":"web-qa-agent","detect_pattern":"package.json","command":"agent:prompts/web-qa-agent-prompt.md","blocking":false,"timeout":300,"execution":"agent"}]}'
TMPDIR_WEB=$(make_git_project "$WEB_ONLY_JSON" "package.json" '{"name":"my-next-app","dependencies":{"next":"14.0.0"}}')
trap 'rm -rf "$TMPDIR_WEB"' EXIT

output=$(cd "$TMPDIR_WEB" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_contains "package.json present → detects web-qa-agent" "web-qa-agent" "$output"

trap - EXIT
rm -rf "$TMPDIR_WEB"

# Test 2: No match — project without package.json → web QA agent NOT invoked
echo ""
echo "-- No web detection (no package.json) --"
WEB_ONLY_JSON='{"agents":[{"name":"web-qa-agent","detect_pattern":"package.json","command":"agent:prompts/web-qa-agent-prompt.md","blocking":false,"timeout":300,"execution":"agent"}]}'
TMPDIR_NOWEB=$(make_git_project "$WEB_ONLY_JSON" "")
trap 'rm -rf "$TMPDIR_NOWEB"' EXIT

output=$(cd "$TMPDIR_NOWEB" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_empty "no package.json → web-qa-agent NOT detected" "$output"

(cd "$TMPDIR_NOWEB" && bash "$DETECT_SCRIPT" >/dev/null 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "  ✅ non-web project → exit 0 (no error)"
  (( PASS++ )) || true
else
  echo "  ❌ non-web project → unexpected exit code $exit_code"
  (( FAIL++ )) || true
fi

trap - EXIT
rm -rf "$TMPDIR_NOWEB"

# Test 3: Multi-platform — both iOS and web agents returned for mixed project
echo ""
echo "-- Multi-platform detection (iOS + web) --"
MULTI_JSON='{"agents":[{"name":"ios-qa-agent","detect_pattern":"*.xcodeproj","command":"agent:prompts/qa-agent-prompt.md","blocking":false,"timeout":300,"execution":"agent"},{"name":"web-qa-agent","detect_pattern":"package.json","command":"agent:prompts/web-qa-agent-prompt.md","blocking":false,"timeout":300,"execution":"agent"}]}'
TMPDIR_MIXED=$(make_git_project "$MULTI_JSON" "package.json" '{"name":"mixed-app"}')
trap 'rm -rf "$TMPDIR_MIXED"' EXIT
mkdir -p "$TMPDIR_MIXED/App.xcodeproj"

output=$(cd "$TMPDIR_MIXED" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_contains "mixed project → ios-qa-agent detected" "ios-qa-agent" "$output"
assert_contains "mixed project → web-qa-agent detected" "web-qa-agent" "$output"

# Verify both agents appear as separate JSON lines
ios_count=$(printf '%s\n' "$output" | grep -c "ios-qa-agent" || true)
web_count=$(printf '%s\n' "$output" | grep -c "web-qa-agent" || true)
if [ "$ios_count" -eq 1 ] && [ "$web_count" -eq 1 ]; then
  echo "  ✅ both agents returned as separate entries"
  (( PASS++ )) || true
else
  echo "  ❌ expected 1 ios + 1 web agent; got ios=$ios_count web=$web_count"
  (( FAIL++ )) || true
fi

trap - EXIT
rm -rf "$TMPDIR_MIXED"

# Test 4: Pure iOS project — web QA agent NOT returned
echo ""
echo "-- Pure iOS project — web agent not detected --"
IOS_ONLY_JSON='{"agents":[{"name":"ios-qa-agent","detect_pattern":"*.xcodeproj","command":"agent:prompts/qa-agent-prompt.md","blocking":false,"timeout":300,"execution":"agent"},{"name":"web-qa-agent","detect_pattern":"package.json","command":"agent:prompts/web-qa-agent-prompt.md","blocking":false,"timeout":300,"execution":"agent"}]}'
TMPDIR_IOS=$(make_git_project "$IOS_ONLY_JSON" "")
trap 'rm -rf "$TMPDIR_IOS"' EXIT
mkdir -p "$TMPDIR_IOS/App.xcodeproj"

output=$(cd "$TMPDIR_IOS" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_contains "iOS-only project → ios-qa-agent detected" "ios-qa-agent" "$output"
assert_not_contains "iOS-only project → web-qa-agent NOT detected" "web-qa-agent" "$output"

trap - EXIT
rm -rf "$TMPDIR_IOS"

# Test 5: detect-agents returns execution field
echo ""
echo "-- detect-agents output structure --"
WEB_EXEC_JSON='{"agents":[{"name":"web-qa-agent","detect_pattern":"package.json","command":"agent:prompts/web-qa-agent-prompt.md","blocking":false,"timeout":300,"execution":"agent"}]}'
TMPDIR_EXEC=$(make_git_project "$WEB_EXEC_JSON" "package.json" '{}')
trap 'rm -rf "$TMPDIR_EXEC"' EXIT

output=$(cd "$TMPDIR_EXEC" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_contains "detect output has command field" "command" "$output"
assert_contains "detect output has blocking field" "blocking" "$output"

trap - EXIT
rm -rf "$TMPDIR_EXEC"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
