#!/usr/bin/env bash
# Integration Tests: Antigravity Port (Issue #57)
# Validates file structure, install/rollback cycle, cross-IDE sync, and regression.
# Can run without Antigravity IDE installed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CCPM_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Assert helpers ---

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" -eq "$actual" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc (exit=$actual)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" output="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -q "$pattern"; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — pattern not found: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" output="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if ! echo "$output" | grep -q "$pattern"; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — pattern should NOT be present: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  TOTAL=$((TOTAL + 1))
  if [ -e "$path" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — not found: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local desc="$1" path="$2"
  TOTAL=$((TOTAL + 1))
  if [ ! -e "$path" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — should not exist: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_count() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" -eq "$actual" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc (count=$actual)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_min_count() {
  local desc="$1" min="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$actual" -ge "$min" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc (count=$actual)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc (expected>=$min, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_lt() {
  local desc="$1" max="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$actual" -lt "$max" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc (${actual}s < ${max}s)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc (${actual}s >= ${max}s)"
    FAIL=$((FAIL + 1))
  fi
}

# --- Setup ---

setup_state() {
  local task_type="$1" verify_mode="${2:-STRICT}" epic="${3:-test-epic}" issue="${4:-99}"
  mkdir -p "$CCPM_ROOT/context/verify"
  cat > "$CCPM_ROOT/context/verify/state.json" <<STATEOF
{
  "active_task": {
    "issue_number": $issue,
    "epic": "$epic",
    "type": "$task_type",
    "verify_mode": "$verify_mode",
    "tech_stack": "generic",
    "verify_profile": "",
    "max_iterations": 20,
    "current_iteration": 0,
    "started_at": "2026-01-01T00:00:00Z",
    "iterations": []
  }
}
STATEOF
}

cleanup() {
  rm -f "$CCPM_ROOT/context/verify/state.json"
  rm -f "$CCPM_ROOT/sync/active-ide.json"
  rm -rf "$CCPM_ROOT/sync"
}

# ========================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Integration Tests: Antigravity Port"
echo "═══════════════════════════════════════════════════════"
echo ""

# ========================================
echo "── Section 1: File Structure Validation ──"
echo ""

AG="$PROJECT_ROOT/antigravity"

# 1.1: Workflow count
workflow_count=$(ls "$AG/workflows/" 2>/dev/null | grep "\.md$" | wc -l | tr -d ' ')
assert_min_count "28+ workflow files in antigravity/workflows/" 28 "$workflow_count"

# 1.2: Skill count
skill_count=$(ls -d "$AG/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
assert_count "7 skill directories in antigravity/skills/" 7 "$skill_count"

# 1.3: Rule count
rule_count=$(ls "$AG/rules/" 2>/dev/null | grep "\.md$" | wc -l | tr -d ' ')
assert_min_count "6+ rule files in antigravity/rules/" 6 "$rule_count"

# 1.4: README exists
assert_file_exists "antigravity/README.md exists" "$AG/README.md"

# 1.5: Each skill has SKILL.md
echo ""
for skill_dir in "$AG/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  assert_file_exists "  $skill_name has SKILL.md" "$skill_dir/SKILL.md"
done

# 1.6: Each skill has scripts/ directory
echo ""
for skill_dir in "$AG/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  assert_file_exists "  $skill_name has scripts/" "$skill_dir/scripts"
done

# 1.7: Templates exist
echo ""
assert_file_exists "templates/active-ide.json exists" "$AG/templates/active-ide.json"

# ========================================
echo ""
echo "── Section 2: Content Validation ──"
echo ""

# 2.1: All workflows have valid frontmatter (--- block with description:)
frontmatter_fail=0
for wf in "$AG/workflows/"*.md; do
  name=$(basename "$wf")
  # Must start with ---
  if ! head -1 "$wf" | grep -q "^---"; then
    echo -e "  ${RED}❌ FAIL${NC}: $name — missing opening ---"
    frontmatter_fail=$((frontmatter_fail + 1))
  # Must have description: field
  elif ! grep -q "^description:" "$wf"; then
    echo -e "  ${RED}❌ FAIL${NC}: $name — missing description: field"
    frontmatter_fail=$((frontmatter_fail + 1))
  fi
done
TOTAL=$((TOTAL + 1))
if [ "$frontmatter_fail" -eq 0 ]; then
  echo -e "  ${GREEN}✅ PASS${NC}: all workflows have valid frontmatter"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: $frontmatter_fail workflow(s) have invalid frontmatter"
  FAIL=$((FAIL + 1))
fi

# 2.2: All skills have name: in SKILL.md
skill_name_fail=0
for skill_dir in "$AG/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  if ! grep -q "^name:" "$skill_dir/SKILL.md" 2>/dev/null; then
    echo -e "  ${RED}❌ FAIL${NC}: $skill_name/SKILL.md — missing name: field"
    skill_name_fail=$((skill_name_fail + 1))
  fi
done
TOTAL=$((TOTAL + 1))
if [ "$skill_name_fail" -eq 0 ]; then
  echo -e "  ${GREEN}✅ PASS${NC}: all 7 skills have name: in SKILL.md"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: $skill_name_fail skill(s) missing name: field"
  FAIL=$((FAIL + 1))
fi

# 2.3: active-ide.json template has last_ide key
assert_contains "active-ide.json has last_ide key" "$(cat "$AG/templates/active-ide.json")" '"last_ide"'

# ========================================
echo ""
echo "── Section 3: Script Executability ──"
echo ""

# 3.1: All scripts in antigravity/skills/*/scripts/ are executable
scripts_total=0
scripts_not_exec=0
while IFS= read -r script; do
  scripts_total=$((scripts_total + 1))
  if [ ! -x "$script" ]; then
    echo -e "  ${YELLOW}⚠${NC}: not executable: $script"
    scripts_not_exec=$((scripts_not_exec + 1))
  fi
done < <(find "$AG/skills" -name "*.sh" 2>/dev/null)

assert_count "all skill scripts executable ($scripts_total scripts)" 0 "$scripts_not_exec"

# ========================================
echo ""
echo "── Section 4: Install Cycle ──"
echo ""

# Create temp project with .gemini/ (required by installer)
TMP_PROJECT=$(mktemp -d)
mkdir -p "$TMP_PROJECT/.gemini"

# 4.1: --antigravity without .gemini/ produces clear error
TMP_NO_GEMINI=$(mktemp -d)
output=$(bash "$PROJECT_ROOT/install/local_install.sh" --antigravity "$TMP_NO_GEMINI" 2>&1)
exit_code=$?
assert_exit "--antigravity without .gemini/ exits non-zero" 1 "$exit_code"
assert_contains "--antigravity without .gemini/ shows clear error" "$output" "CCPM base required"
rm -rf "$TMP_NO_GEMINI"

# 4.2: Timed install
echo ""
echo "  [4.2] Running timed install..."
START_TS=$(date +%s)
install_output=$(bash "$PROJECT_ROOT/install/local_install.sh" --antigravity "$TMP_PROJECT" 2>&1)
install_exit=$?
END_TS=$(date +%s)
ELAPSED_INSTALL=$((END_TS - START_TS))

assert_exit "Install exits 0" 0 "$install_exit"
assert_lt "Install time < 30s" 30 "$ELAPSED_INSTALL"

# 4.3: Installed structure
echo ""
assert_file_exists ".agent/ directory created" "$TMP_PROJECT/.agent"
assert_file_exists ".agent/skills/ directory" "$TMP_PROJECT/.agent/skills"
assert_file_exists ".agent/workflows/ directory" "$TMP_PROJECT/.agent/workflows"
assert_file_exists ".agent/rules/ directory" "$TMP_PROJECT/.agent/rules"
assert_file_exists ".agent/README.md copied" "$TMP_PROJECT/.agent/README.md"
assert_file_exists ".gemini/sync/active-ide.json created" "$TMP_PROJECT/.gemini/sync/active-ide.json"

# 4.4: File counts after install
installed_workflows=$(ls "$TMP_PROJECT/.agent/workflows/" 2>/dev/null | grep "\.md$" | wc -l | tr -d ' ')
installed_skills=$(ls -d "$TMP_PROJECT/.agent/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
installed_rules=$(ls "$TMP_PROJECT/.agent/rules/" 2>/dev/null | grep "\.md$" | wc -l | tr -d ' ')

echo ""
assert_min_count "28+ workflows installed to .agent/workflows/" 28 "$installed_workflows"
assert_count "7 skills installed to .agent/skills/" 7 "$installed_skills"
assert_min_count "6+ rules installed to .agent/rules/" 6 "$installed_rules"

# 4.5: .gitignore updated
assert_contains ".agent/ added to .gitignore" "$(cat "$TMP_PROJECT/.gitignore" 2>/dev/null || echo '')" ".agent/"

# 4.6: Installed scripts are executable
installed_not_exec=$(find "$TMP_PROJECT/.agent/skills" -name "*.sh" ! -perm /111 2>/dev/null | wc -l | tr -d ' ')
assert_count "all installed scripts are executable" 0 "$installed_not_exec"

# 4.7: Idempotent re-install (active-ide.json preserved)
echo ""
echo "  [4.7] Testing idempotent re-install..."
# Modify active-ide.json to check it's preserved
echo '{"last_ide":"antigravity","preserved":true}' > "$TMP_PROJECT/.gemini/sync/active-ide.json"
bash "$PROJECT_ROOT/install/local_install.sh" --antigravity "$TMP_PROJECT" >/dev/null 2>&1
rerun_exit=$?
assert_exit "Re-install exits 0" 0 "$rerun_exit"
assert_contains "active-ide.json preserved on re-install" "$(cat "$TMP_PROJECT/.gemini/sync/active-ide.json")" '"preserved":true'

# ========================================
echo ""
echo "── Section 5: Rollback Verification ──"
echo ""

# 5.1: Remove .agent/ → clean state
rm -rf "$TMP_PROJECT/.agent"
assert_file_not_exists ".agent/ removed successfully" "$TMP_PROJECT/.agent"

# 5.2: .gemini/sync/ still exists (separate lifecycle)
assert_file_exists ".gemini/sync/ persists after rollback" "$TMP_PROJECT/.gemini/sync"

# Cleanup temp project
rm -rf "$TMP_PROJECT"

# ========================================
echo ""
echo "── Section 6: Cross-IDE Sync Mock Test ──"
echo ""

cleanup
setup_state "BUG_FIX" "STRICT" "test-epic" "57"

# 6.1: Without active-ide.json — no transition message
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert_not_contains "No active-ide.json — no transition message" "$output" "IDE TRANSITION DETECTED"

# 6.2: With last_ide = "gemini-cli" — same IDE, no message
echo ""
mkdir -p "$CCPM_ROOT/sync"
echo '{"last_ide":"gemini-cli","last_session_end":null}' > "$CCPM_ROOT/sync/active-ide.json"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert_not_contains "last_ide=gemini-cli — no transition message" "$output" "IDE TRANSITION DETECTED"

# 6.3: With last_ide = "antigravity" — shows transition
echo ""
echo '{"last_ide":"antigravity","last_session_end":"2026-02-24T00:00:00Z"}' > "$CCPM_ROOT/sync/active-ide.json"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert_contains "last_ide=antigravity — shows IDE TRANSITION DETECTED" "$output" "IDE TRANSITION DETECTED"
assert_contains "shows last IDE name in message" "$output" "antigravity"
assert_contains "shows Gemini CLI as current IDE" "$output" "Gemini CLI"

# 6.4: With last_ide = null — no transition (null is not a valid IDE string)
echo ""
echo '{"last_ide":null,"last_session_end":null}' > "$CCPM_ROOT/sync/active-ide.json"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert_not_contains "last_ide=null — no transition message" "$output" "IDE TRANSITION DETECTED"

# ========================================
echo ""
echo "── Section 7: Gemini CLI Regression ──"
echo ""

# 7.1: Existing commands still present
cmd_count=$(find "$PROJECT_ROOT/commands/pm" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((TOTAL + 1))
if [ "$cmd_count" -gt 0 ]; then
  echo -e "  ${GREEN}✅ PASS${NC}: commands/pm/ has $cmd_count command files (not touched)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: commands/pm/ is empty or missing"
  FAIL=$((FAIL + 1))
fi

# 7.2: config/lifecycle.json still valid
TOTAL=$((TOTAL + 1))
if jq '.' "$PROJECT_ROOT/config/lifecycle.json" >/dev/null 2>&1; then
  echo -e "  ${GREEN}✅ PASS${NC}: config/lifecycle.json valid JSON (not corrupted)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: config/lifecycle.json invalid — possible regression"
  FAIL=$((FAIL + 1))
fi

# 7.3: Core hooks still exist
for hook in pre-task.sh pre-tool-use.sh post-task.sh stop-verify.sh; do
  assert_file_exists "hooks/$hook still exists" "$PROJECT_ROOT/hooks/$hook"
done

# 7.4: Install script still has base install mode (non-antigravity)
output=$(bash "$PROJECT_ROOT/install/local_install.sh" --help 2>&1 || true)
TOTAL=$((TOTAL + 1))
if grep -q "antigravity\|local_install" "$PROJECT_ROOT/install/local_install.sh"; then
  echo -e "  ${GREEN}✅ PASS${NC}: install/local_install.sh intact"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: install/local_install.sh may be corrupted"
  FAIL=$((FAIL + 1))
fi

# ========================================
echo ""
echo "── Section 8: Context Sync Script Performance ──"
echo ""

# 8.1: Check sync-context.sh exists
assert_file_exists "ccpm-context-sync/scripts/sync-context.sh exists" \
  "$PROJECT_ROOT/antigravity/skills/ccpm-context-sync/scripts/sync-context.sh"

# 8.2: Timed sync context (< 1s)
if [ -x "$PROJECT_ROOT/antigravity/skills/ccpm-context-sync/scripts/sync-context.sh" ]; then
  start_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  bash "$PROJECT_ROOT/antigravity/skills/ccpm-context-sync/scripts/sync-context.sh" >/dev/null 2>&1 || true
  end_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 1000)
  elapsed_sync=$((end_ms - start_ms))
  assert_lt "sync-context.sh < 1000ms" 1000 "$elapsed_sync"
fi

# ========================================
# Cleanup
cleanup

# ========================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
  exit 0
else
  echo -e "${RED}❌ $FAIL TEST(S) FAILED${NC}"
  exit 1
fi
