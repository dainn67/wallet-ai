#!/usr/bin/env bash
# Detect if Superpowers plugin is installed.
# Exit 0 = installed, Exit 1 = not installed
# Stdout: "superpowers:installed" or "superpowers:not-installed"

set -euo pipefail

# Check 1: .claude-plugin/plugin.json contains "superpowers" in name
if [ -f ".claude-plugin/plugin.json" ]; then
  if command -v jq &>/dev/null; then
    name=$(jq -r '.name // ""' ".claude-plugin/plugin.json" 2>/dev/null || echo "")
  else
    name=$(python3 -c "
import json
with open('.claude-plugin/plugin.json') as f:
    print(json.load(f).get('name', ''))
" 2>/dev/null || echo "")
  fi
  if echo "$name" | grep -qi "superpowers"; then
    echo "superpowers:installed"
    exit 0
  fi
fi

# Check 2: Scan .claude-plugin/skills/*/SKILL.md for known skill names
KNOWN_SKILLS="brainstorming|tdd|code-review|systematic-debugging|finishing-branch"
if [ -d ".claude-plugin/skills" ]; then
  for skill_file in .claude-plugin/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    if grep -qiE "$KNOWN_SKILLS" "$skill_file" 2>/dev/null; then
      echo "superpowers:installed"
      exit 0
    fi
  done
fi

# Check 3: Global Claude Code plugin (installed via /plugin install)
_settings_file="$HOME/.claude/settings.json"
if [ -f "$_settings_file" ]; then
  if grep -q '"superpowers' "$_settings_file" 2>/dev/null; then
    _global_cache="$HOME/.claude/plugins/cache"
    if [ -d "$_global_cache" ]; then
      for _sp_dir in "$_global_cache"/*/superpowers; do
        if [ -d "$_sp_dir" ]; then
          echo "superpowers:installed"
          exit 0
        fi
      done
    fi
  fi
fi

echo "superpowers:not-installed"
exit 1
