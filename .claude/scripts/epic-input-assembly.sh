#!/bin/bash
# Epic Input Assembly — Collect all data sources for Phase A Semantic Review
#
# Usage: ./epic-input-assembly.sh <epic-name> <output-dir>
#
# Collects 15 data sources into numbered files (01- to 15-).
# P0 (required): Fails if critical sources missing
# P1 (important): Warns if missing
# P2 (nice-to-have): Skips silently if missing

set -euo pipefail

EPIC_NAME="${1:?Usage: epic-input-assembly.sh <epic-name> <output-dir>}"
OUTPUT_DIR="${2:?Usage: epic-input-assembly.sh <epic-name> <output-dir>}"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$OUTPUT_DIR"

# Detect GitHub repo (smart: epic config → mapping → git remote)
CCPM_ROOT="${PROJECT_ROOT}/.claude"
GH_HELPERS="$CCPM_ROOT/scripts/pm/github-helpers.sh"
REPO=""
if [ -f "$GH_HELPERS" ]; then
  # Source helpers to use get_repo directly
  source "$GH_HELPERS"
  REPO=$(get_repo 2>/dev/null || echo "")
fi
if [ -z "$REPO" ]; then
  REPO=$(git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||;s|\.git$||' || echo "")
fi
REPO_FLAG=""
if [ -n "$REPO" ]; then
  REPO_FLAG="--repo $REPO"
fi

COLLECTED=0
WARNED=0
SKIPPED=0

echo "═══ Epic Input Assembly: $EPIC_NAME ═══"
echo "Started: $TIMESTAMP"
[ -n "$REPO" ] && echo "Repository: $REPO"
echo ""

# ═══════════════════════════════════════════════════════════════
# Fetch all issues with epic label (single GitHub API call)
# ═══════════════════════════════════════════════════════════════
echo "Fetching issues from GitHub..."
if ! gh issue list $REPO_FLAG --label "epic:$EPIC_NAME" --state all \
  --json number,title,body,state,labels,closedAt \
  --limit 100 > "$TMP_DIR/all-issues.json" 2>/dev/null; then
  echo "❌ P0 FAIL: Cannot fetch issues. Run: gh auth login"
  exit 1
fi

ISSUE_COUNT=$(python3 -c "import json; print(len(json.load(open('$TMP_DIR/all-issues.json'))))")

if [ "$ISSUE_COUNT" -eq 0 ]; then
  # Fallback: search by title
  echo "No issues with label 'epic:$EPIC_NAME', trying title search..."
  if ! gh issue list $REPO_FLAG --search "Epic: $EPIC_NAME in:title" --state all \
    --json number,title,body,state,labels,closedAt \
    --limit 100 > "$TMP_DIR/all-issues.json" 2>/dev/null; then
    echo "❌ P0 FAIL: Cannot fetch issues"
    exit 1
  fi
  ISSUE_COUNT=$(python3 -c "import json; print(len(json.load(open('$TMP_DIR/all-issues.json'))))")
fi

if [ "$ISSUE_COUNT" -eq 0 ]; then
  echo "❌ P0 FAIL: No issues found for epic '$EPIC_NAME'"
  exit 1
fi

echo "Found $ISSUE_COUNT issues"
echo ""

# ═══════════════════════════════════════════════════════════════
# Items 01-05: From cached GitHub data (P0)
# ═══════════════════════════════════════════════════════════════
python3 - "$TMP_DIR/all-issues.json" "$OUTPUT_DIR" "$EPIC_NAME" "$TIMESTAMP" << 'PYEOF'
import json, os, sys, re

issues_file, output_dir, epic_name, timestamp = sys.argv[1:5]

with open(issues_file) as f:
    data = json.load(f)

if not data:
    print("❌ P0 FAIL: No issues found", file=sys.stderr)
    sys.exit(1)

all_issues = sorted(data, key=lambda x: x['number'])
header = f"<!-- Source: {{}} | Collected: {timestamp} | Epic: {epic_name} -->\n\n"

# Separate epic issue from task issues
epic_issue = None
for issue in all_issues:
    labels = [l['name'] for l in issue.get('labels', [])]
    if 'task' not in labels:
        epic_issue = issue
        break

if epic_issue is None:
    # Fallback: issue with title containing "Epic:"
    for issue in all_issues:
        if issue['title'].lower().startswith('epic:') or 'epic:' in issue['title'].lower():
            epic_issue = issue
            break

if epic_issue is None:
    epic_issue = all_issues[0]

# ── 01. Epic Description ──
with open(f'{output_dir}/01-epic-description.md', 'w') as f:
    f.write(header.format(f"GitHub Issue #{epic_issue['number']}"))
    f.write(f"# Epic: {epic_issue['title']}\n\n")
    f.write(epic_issue.get('body', '') or 'No description')
    f.write('\n')
print("✅ 01-epic-description.md")

# ── 02. Acceptance Criteria ──
body = epic_issue.get('body', '') or ''
ac_match = re.search(r'##\s*Acceptance Criteria\s*\n(.*?)(?=\n##|\Z)', body, re.DOTALL)
if ac_match:
    criteria = ac_match.group(1).strip()
else:
    checkboxes = re.findall(r'- \[[ x]\] .+', body)
    if checkboxes:
        criteria = '\n'.join(checkboxes)
    else:
        req_match = re.search(r'##\s*Requirements?\s*\n(.*?)(?=\n##|\Z)', body, re.DOTALL)
        if req_match:
            criteria = req_match.group(1).strip()
        else:
            criteria = ('No explicit acceptance criteria found.\n'
                       'Full epic description will be used as criteria reference.')

with open(f'{output_dir}/02-acceptance-criteria.md', 'w') as f:
    f.write(header.format("Extracted from epic description"))
    f.write("# Acceptance Criteria\n\n")
    f.write(criteria + '\n')

criteria_lines = [l for l in criteria.split('\n') if l.strip().startswith('- ')]
print(f"✅ 02-acceptance-criteria.md ({len(criteria_lines)} items)")

# ── 03. Issue List ──
open_count = sum(1 for i in all_issues if i['state'] == 'OPEN')
closed_count = sum(1 for i in all_issues if i['state'] == 'CLOSED')

with open(f'{output_dir}/03-issue-list.md', 'w') as f:
    f.write(header.format("GitHub Issues API"))
    f.write(f"# Issues in Epic: {epic_name}\n\n")
    f.write(f"Total: {len(all_issues)} | Closed: {closed_count} | Open: {open_count}\n\n")
    f.write("| # | Title | State | Labels |\n")
    f.write("|---|-------|-------|--------|\n")
    for issue in all_issues:
        labels = ', '.join(l['name'] for l in issue.get('labels', []))
        emoji = '✅' if issue['state'] == 'CLOSED' else '🔄'
        title = issue['title'].replace('|', '\\|')
        f.write(f"| {emoji} #{issue['number']} | {title} | {issue['state']} | {labels} |\n")
    f.write('\n')
print(f"✅ 03-issue-list.md ({len(all_issues)} issues)")

# ── 04. Issue Descriptions ──
truncate = len(all_issues) > 20
max_chars = 4000 if truncate else None  # ~1k tokens

with open(f'{output_dir}/04-issue-descriptions.md', 'w') as f:
    f.write(header.format("GitHub Issues API"))
    f.write("# Issue Descriptions\n\n")
    if truncate:
        f.write(f"⚠️ {len(all_issues)} issues — descriptions truncated to ~1k tokens each\n\n")
    for issue in all_issues:
        f.write(f"## Issue #{issue['number']}: {issue['title']}\n\n")
        issue_body = issue.get('body', '') or 'No description'
        if truncate and max_chars and len(issue_body) > max_chars:
            issue_body = issue_body[:max_chars] + '\n\n... (truncated)'
        f.write(issue_body + '\n\n---\n\n')
print(f"✅ 04-issue-descriptions.md{' (truncated)' if truncate else ''}")

# ── 05. Issue Status ──
with open(f'{output_dir}/05-issue-status.md', 'w') as f:
    f.write(header.format("GitHub Issues API"))
    f.write("# Issue Status\n\n")
    for issue in all_issues:
        labels = [l['name'] for l in issue.get('labels', [])]
        emoji = '✅' if issue['state'] == 'CLOSED' else '🔄'
        f.write(f"### {emoji} #{issue['number']}: {issue['title']}\n\n")
        f.write(f"- **State:** {issue['state']}\n")
        f.write(f"- **Labels:** {', '.join(labels)}\n")
        if issue.get('closedAt'):
            f.write(f"- **Closed:** {issue['closedAt']}\n")
        f.write('\n')
print(f"✅ 05-issue-status.md")
PYEOF

COLLECTED=5

# ═══════════════════════════════════════════════════════════════
# Items 06-09: Filesystem + Git (P0)
# ═══════════════════════════════════════════════════════════════

# ── 06. Handoff Notes ──
echo "── 06. Handoff Notes ──"
HANDOFF_DIR="$PROJECT_ROOT/.claude/context/handoffs"
{
  echo "<!-- Source: $HANDOFF_DIR | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
  echo ""
  echo "# Handoff Notes"
  echo ""
  found_handoffs=0
  if [ -d "$HANDOFF_DIR" ]; then
    for f in "$HANDOFF_DIR"/*.md "$HANDOFF_DIR"/.archive/*.md; do
      [ -f "$f" ] || continue
      echo "## $(basename "$f")"
      echo ""
      cat "$f"
      echo ""
      echo "---"
      echo ""
      found_handoffs=$((found_handoffs + 1))
    done
  fi
  if [ "$found_handoffs" -eq 0 ]; then
    echo "No handoff notes found."
  fi
} > "$OUTPUT_DIR/06-handoff-notes.md"

if [ -d "$HANDOFF_DIR" ] && ls "$HANDOFF_DIR"/*.md >/dev/null 2>&1; then
  echo "✅ 06-handoff-notes.md"
else
  echo "⚠️ 06-handoff-notes.md (no handoff notes found)"
  WARNED=$((WARNED + 1))
fi
COLLECTED=$((COLLECTED + 1))

# ── 07. Epic Context ──
echo "── 07. Epic Context ──"
EPIC_CTX="$PROJECT_ROOT/.claude/context/epics/${EPIC_NAME}.md"
{
  echo "<!-- Source: $EPIC_CTX | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
  echo ""
  echo "# Epic Context"
  echo ""
  if [ -f "$EPIC_CTX" ]; then
    cat "$EPIC_CTX"
  else
    echo "No epic context file found at .claude/context/epics/${EPIC_NAME}.md"
  fi
} > "$OUTPUT_DIR/07-epic-context.md"

if [ -f "$EPIC_CTX" ]; then
  echo "✅ 07-epic-context.md"
else
  echo "⚠️ 07-epic-context.md (no context file)"
  WARNED=$((WARNED + 1))
fi
COLLECTED=$((COLLECTED + 1))

# ── 08. Architecture Decisions ──
echo "── 08. Architecture Decisions ──"
ARCH_FILE="$PROJECT_ROOT/.claude/context/architecture-decisions.md"
{
  echo "<!-- Source: Architecture decisions | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
  echo ""
  echo "# Architecture Decisions"
  echo ""
  if [ -f "$ARCH_FILE" ]; then
    cat "$ARCH_FILE"
  else
    # Fallback: check epic.md for architecture decisions section
    EPIC_FILE="$PROJECT_ROOT/.claude/epics/$EPIC_NAME/epic.md"
    if [ -f "$EPIC_FILE" ]; then
      python3 -c "
import re, sys
with open('$EPIC_FILE') as f:
    content = f.read()
match = re.search(r'##\s*Architecture Decisions\s*\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
if match:
    print(match.group(0))
else:
    print('No architecture decisions found.')
"
    else
      echo "No architecture decisions found."
    fi
  fi
} > "$OUTPUT_DIR/08-architecture-decisions.md"

if [ -f "$ARCH_FILE" ]; then
  echo "✅ 08-architecture-decisions.md"
else
  echo "⚠️ 08-architecture-decisions.md (extracted from epic.md)"
  WARNED=$((WARNED + 1))
fi
COLLECTED=$((COLLECTED + 1))

# ── 09. Git Log ──
echo "── 09. Git Log ──"
# Get epic created date for filtering
EPIC_CREATED=$(grep "^created:" "$PROJECT_ROOT/.claude/epics/$EPIC_NAME/epic.md" 2>/dev/null \
  | head -1 | sed 's/^created: *//' || echo "")

{
  echo "<!-- Source: git log | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
  echo ""
  echo "# Git Log"
  echo ""

  if [ -n "$EPIC_CREATED" ]; then
    echo "Commits since epic created ($EPIC_CREATED):"
    echo ""
    echo '```'
    git -C "$PROJECT_ROOT" log --oneline --since="$EPIC_CREATED" --no-merges 2>/dev/null \
      | head -200 || echo "No commits found"
    echo '```'
  else
    echo "Recent commits (last 100):"
    echo ""
    echo '```'
    git -C "$PROJECT_ROOT" log --oneline -100 --no-merges 2>/dev/null || echo "No commits found"
    echo '```'
  fi
} > "$OUTPUT_DIR/09-git-log.md"

echo "✅ 09-git-log.md"
COLLECTED=$((COLLECTED + 1))

# ═══════════════════════════════════════════════════════════════
# Items 10-12: P1 (Important) — warn if missing
# ═══════════════════════════════════════════════════════════════

# ── 10. Codebase Structure ──
echo "── 10. Codebase Structure ──"
{
  echo "<!-- Source: filesystem | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
  echo ""
  echo "# Codebase Structure"
  echo ""
  echo '```'
  if command -v tree >/dev/null 2>&1; then
    tree -L 3 -I 'node_modules|.git|__pycache__|.venv|venv|dist|build|.claude' \
      "$PROJECT_ROOT" 2>/dev/null || ls -la "$PROJECT_ROOT"
  else
    # Fallback without tree
    find "$PROJECT_ROOT" -maxdepth 3 \
      -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -not -path '*/__pycache__/*' -not -path '*/.venv/*' \
      -not -path '*/.claude/*' \
      -type f 2>/dev/null | sort | head -200
  fi
  echo '```'
} > "$OUTPUT_DIR/10-codebase-structure.md"

echo "✅ 10-codebase-structure.md"
COLLECTED=$((COLLECTED + 1))

# ── 11. Test Coverage ──
echo "── 11. Test Coverage ──"
{
  echo "<!-- Source: test coverage tools | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
  echo ""
  echo "# Test Coverage Report"
  echo ""

  coverage_found=false
  # Python
  if [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/setup.py" ]; then
    if command -v python3 >/dev/null 2>&1 && python3 -c "import coverage" 2>/dev/null; then
      echo "## Python Coverage"
      echo '```'
      cd "$PROJECT_ROOT" && python3 -m pytest --co -q 2>/dev/null | head -50 || echo "No pytest tests found"
      echo '```'
      coverage_found=true
    fi
  fi
  # Node
  if [ -f "$PROJECT_ROOT/package.json" ]; then
    if [ -f "$PROJECT_ROOT/coverage/coverage-summary.json" ]; then
      echo "## Node.js Coverage"
      echo '```'
      cat "$PROJECT_ROOT/coverage/coverage-summary.json" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    total = data.get('total', {})
    for key in ['lines', 'statements', 'functions', 'branches']:
        if key in total:
            pct = total[key].get('pct', 'N/A')
            print(f'{key}: {pct}%')
except: print('Could not parse coverage')
" 2>/dev/null
      echo '```'
      coverage_found=true
    fi
  fi

  if [ "$coverage_found" = false ]; then
    echo "No test coverage report available."
    echo ""
    echo "To generate coverage, run the appropriate command for your stack:"
    echo "- Python: \`pytest --cov\`"
    echo "- Node: \`npx nyc npm test\`"
    echo "- Go: \`go test -cover ./...\`"
  fi
} > "$OUTPUT_DIR/11-test-coverage.md"

echo "⚠️ 11-test-coverage.md (report may be incomplete)"
WARNED=$((WARNED + 1))
COLLECTED=$((COLLECTED + 1))

# ── 12. Active Interfaces ──
echo "── 12. Active Interfaces ──"
IFACE_FILE="$PROJECT_ROOT/.claude/context/active-interfaces.md"
{
  echo "<!-- Source: $IFACE_FILE | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
  echo ""
  echo "# Active Interfaces"
  echo ""
  if [ -f "$IFACE_FILE" ]; then
    cat "$IFACE_FILE"
  else
    echo "No active-interfaces.md found."
  fi
} > "$OUTPUT_DIR/12-active-interfaces.md"

if [ -f "$IFACE_FILE" ]; then
  echo "✅ 12-active-interfaces.md"
else
  echo "⚠️ 12-active-interfaces.md (not found)"
  WARNED=$((WARNED + 1))
fi
COLLECTED=$((COLLECTED + 1))

# ═══════════════════════════════════════════════════════════════
# Items 13-15: P2 (Nice to have) — skip silently if missing
# ═══════════════════════════════════════════════════════════════

# ── 13. Known Issues ──
KNOWN_FILE="$PROJECT_ROOT/.claude/context/known-issues.md"
if [ -f "$KNOWN_FILE" ]; then
  {
    echo "<!-- Source: $KNOWN_FILE | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
    echo ""
    echo "# Known Issues"
    echo ""
    cat "$KNOWN_FILE"
  } > "$OUTPUT_DIR/13-known-issues.md"
  echo "✅ 13-known-issues.md"
  COLLECTED=$((COLLECTED + 1))
else
  SKIPPED=$((SKIPPED + 1))
fi

# ── 14. Previous Epic Verify Reports ──
REPORTS_DIR="$PROJECT_ROOT/.claude/context/verify/epic-reports"
if [ -d "$REPORTS_DIR" ] && ls "$REPORTS_DIR"/${EPIC_NAME}-*.md >/dev/null 2>&1; then
  LATEST_REPORT=$(ls -t "$REPORTS_DIR"/${EPIC_NAME}-*.md 2>/dev/null | head -1)
  {
    echo "<!-- Source: $LATEST_REPORT | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
    echo ""
    echo "# Previous Epic Verify Report"
    echo ""
    cat "$LATEST_REPORT"
  } > "$OUTPUT_DIR/14-previous-reports.md"
  echo "✅ 14-previous-reports.md"
  COLLECTED=$((COLLECTED + 1))
else
  SKIPPED=$((SKIPPED + 1))
fi

# ── 15. Diff Summary ──
MERGE_BASE=$(git -C "$PROJECT_ROOT" merge-base main HEAD 2>/dev/null || echo "")
if [ -n "$MERGE_BASE" ] && [ "$MERGE_BASE" != "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" ]; then
  {
    echo "<!-- Source: git diff | Collected: $TIMESTAMP | Epic: $EPIC_NAME -->"
    echo ""
    echo "# Diff Summary"
    echo ""
    echo "Changes from \`$(echo "$MERGE_BASE" | cut -c1-8)\` to \`HEAD\`:"
    echo ""
    echo '```'
    git -C "$PROJECT_ROOT" diff "$MERGE_BASE"..HEAD --stat 2>/dev/null || echo "No diff available"
    echo '```'
  } > "$OUTPUT_DIR/15-diff-summary.md"
  echo "✅ 15-diff-summary.md"
  COLLECTED=$((COLLECTED + 1))
else
  SKIPPED=$((SKIPPED + 1))
fi

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════"
echo "✅ Input Assembly complete: $OUTPUT_DIR/"
echo ""
echo "  Collected: $COLLECTED files"
echo "  Warnings:  $WARNED"
echo "  Skipped:   $SKIPPED (P2 sources not available)"
echo ""
ls -1 "$OUTPUT_DIR"/*.md 2>/dev/null | while read -r f; do
  size=$(wc -c < "$f" | tr -d ' ')
  echo "  $(basename "$f") (${size}B)"
done
echo ""
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
echo "  Total size: $TOTAL_SIZE"
echo "═══════════════════════════════════════════"
