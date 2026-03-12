#!/usr/bin/env bash
# Detect if UUPM (ui-ux-pro-max) skill is installed.
# Exit 0 = installed, Exit 1 = not installed
# Stdout: path to UUPM or "uupm:not-installed"

set -euo pipefail

SKILL_DIR="ui-ux-pro-max"
SKILL_MARKER="SKILL.md"

# Check 1: Local plugin install — .gemini-plugin/skills/ui-ux-pro-max/
_local_path=".gemini-plugin/skills/${SKILL_DIR}"
if [ -d "$_local_path" ]; then
  if [ -f "${_local_path}/${SKILL_MARKER}" ] || [ -f "${_local_path}/search.py" ]; then
    echo "$_local_path"
    exit 0
  fi
fi

# Check 2: Home directory global install
_home_path="$HOME/.gemini-plugin/skills/${SKILL_DIR}"
if [ -d "$_home_path" ]; then
  if [ -f "${_home_path}/${SKILL_MARKER}" ] || [ -f "${_home_path}/search.py" ]; then
    echo "$_home_path"
    exit 0
  fi
fi

# Check 3: GEMINI_PLUGIN_PATH env var
if [ -n "${GEMINI_PLUGIN_PATH:-}" ] && [ -d "${GEMINI_PLUGIN_PATH}/skills/${SKILL_DIR}" ]; then
  _env_path="${GEMINI_PLUGIN_PATH}/skills/${SKILL_DIR}"
  if [ -f "${_env_path}/${SKILL_MARKER}" ] || [ -f "${_env_path}/search.py" ]; then
    echo "$_env_path"
    exit 0
  fi
fi

# Check 4: Scan .gemini-plugin/skills/*/SKILL.md for UUPM skill name
if [ -d ".gemini-plugin/skills" ]; then
  for skill_file in .gemini-plugin/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    if grep -qi "ui-ux-pro-max\|uupm" "$skill_file" 2>/dev/null; then
      dirname "$skill_file"
      exit 0
    fi
  done
fi

echo "uupm:not-installed"
exit 1
