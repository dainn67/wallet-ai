#!/bin/bash
# generate-tests.sh — Generate Playwright test files from QA scenario results JSON
# Usage: echo '<json>' | bash generate-tests.sh [output_dir]
#        bash generate-tests.sh [output_dir] < results.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE="$SCRIPT_DIR/test-templates/web-test.template.ts"

# Determine output directory
# Priority: arg > playwright.config.ts testDir > default
OUTPUT_DIR="${1:-}"

if [ -z "$OUTPUT_DIR" ]; then
  # Check for playwright.config.ts in repo root and extract testDir
  if [ -f "$REPO_ROOT/playwright.config.ts" ]; then
    DETECTED=$(grep -oP "testDir:\s*['\"]([^'\"]+)['\"]" "$REPO_ROOT/playwright.config.ts" 2>/dev/null \
      | grep -oP "['\"]([^'\"]+)['\"]" | tr -d "'\"" || echo "")
    if [ -n "$DETECTED" ]; then
      OUTPUT_DIR="$REPO_ROOT/$DETECTED/web-qa-generated"
    fi
  fi
  if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$REPO_ROOT/tests/e2e/web-qa-generated"
  fi
fi

mkdir -p "$OUTPUT_DIR"

# Read stdin into variable so Python can receive it via environment
INPUT=$(cat)

if [ -z "$INPUT" ]; then
  echo "❌ No input provided. Pipe QA scenario results JSON via stdin." >&2
  exit 1
fi

export _GENERATE_INPUT="$INPUT"
export _GENERATE_TEMPLATE="$TEMPLATE"
export _GENERATE_OUTPUT_DIR="$OUTPUT_DIR"

python3 - <<'PYEOF'
import sys
import json
import re
import os

output_dir = os.environ['_GENERATE_OUTPUT_DIR']
template_path = os.environ['_GENERATE_TEMPLATE']

with open(template_path) as f:
    template = f.read()

input_json = os.environ.get('_GENERATE_INPUT', '')
if not input_json:
    print('❌ Internal error: no input JSON', file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(input_json)
except json.JSONDecodeError as e:
    print(f'❌ Invalid JSON: {e}', file=sys.stderr)
    sys.exit(1)

scenarios = data.get('scenarios', [])
if not scenarios:
    print('❌ No scenarios found in input JSON', file=sys.stderr)
    sys.exit(1)

def escape_ts_string(s):
    """Escape string for TypeScript single-quoted string."""
    return s.replace('\\', '\\\\').replace("'", "\\'")

def ref_to_locator_expr(ref_id, selectors, refs_list):
    """
    Resolve a ref (@eN) to a full Playwright locator expression string.
    selectors: dict mapping ref id -> selector string (e.g. {"@e1": "button >> text=Submit"})
    refs_list: list of {ref, selector, role, name} objects
    Returns e.g. "page.locator('button >> text=Submit')" or "page.getByRole('button', { name: 'Submit' })"
    """
    # Try direct selector map first
    if selectors and ref_id in selectors:
        sel = selectors[ref_id]
        return f"page.locator('{escape_ts_string(sel)}')"

    # Try refs_list format
    if refs_list:
        for entry in refs_list:
            if entry.get('ref') == ref_id:
                if entry.get('selector'):
                    return f"page.locator('{escape_ts_string(entry['selector'])}')"
                role = entry.get('role', 'button')
                name = entry.get('name', '')
                if name:
                    return f"page.getByRole('{escape_ts_string(role)}', {{ name: '{escape_ts_string(name)}' }})"
                return f"page.getByRole('{escape_ts_string(role)}')"

    # No mapping found — use generic locator
    return f"page.locator('[data-ref=\"{ref_id}\"]')"

def step_to_playwright(step, selectors, refs_list):
    """Convert a single scenario step dict to a Playwright TypeScript line."""
    command = step.get('command', '')
    args = step.get('args', [])

    if command == 'goto':
        url = args[0] if args else ''
        return f"await page.goto('{escape_ts_string(url)}');"

    elif command == 'click':
        ref_id = args[0] if args else '@e1'
        locator = ref_to_locator_expr(ref_id, selectors, refs_list)
        return f"await {locator}.click();"

    elif command == 'fill':
        ref_id = args[0] if args else '@e1'
        value = args[1] if len(args) > 1 else ''
        locator = ref_to_locator_expr(ref_id, selectors, refs_list)
        return f"await {locator}.fill('{escape_ts_string(value)}');"

    elif command == 'select':
        ref_id = args[0] if args else '@e1'
        value = args[1] if len(args) > 1 else ''
        locator = ref_to_locator_expr(ref_id, selectors, refs_list)
        return f"await {locator}.selectOption('{escape_ts_string(value)}');"

    elif command in ('snapshot', 'assert', 'assertion'):
        if args:
            ref_id = args[0]
            locator = ref_to_locator_expr(ref_id, selectors, refs_list)
            return f"await expect({locator}).toBeVisible();"
        else:
            return "await expect(page).toHaveTitle(/.+/);"

    elif command == 'screenshot':
        path = args[0] if args else 'screenshot.png'
        return f"await page.screenshot({{ path: '{escape_ts_string(path)}' }});"

    elif command == 'hover':
        ref_id = args[0] if args else '@e1'
        locator = ref_to_locator_expr(ref_id, selectors, refs_list)
        return f"await {locator}.hover();"

    elif command == 'press':
        key = args[0] if args else 'Enter'
        return f"await page.keyboard.press('{escape_ts_string(key)}');"

    else:
        return f"// TODO: unsupported command '{command}' args={json.dumps(args)}"

def scenario_to_filename(name):
    """Convert scenario name to safe filename."""
    safe = re.sub(r'[^a-zA-Z0-9_-]', '-', name.lower())
    safe = re.sub(r'-+', '-', safe).strip('-')
    return f"{safe}.spec.ts"

files_written = []

for scenario in scenarios:
    # Skip failed scenarios
    if not scenario.get('passed', True):
        name = scenario.get('name', 'unnamed')
        print(f"  SKIP: '{name}' (not passed)", file=sys.stderr)
        continue

    name = scenario.get('name', 'unnamed test')
    steps = scenario.get('steps', [])
    selectors = scenario.get('selectors', {})  # dict: {"@e1": "selector"}
    refs_list = scenario.get('refs', [])        # list: [{"ref": "@e1", "selector": "...", "role": "..."}]

    step_lines = []
    has_navigation = False
    for step in steps:
        line = step_to_playwright(step, selectors, refs_list)
        step_lines.append(f"  {line}")
        if step.get('command') == 'goto':
            has_navigation = True

    # Navigation-only scenario: add title assertion so test is non-trivial
    if has_navigation and len(step_lines) == 1:
        step_lines.append("  await expect(page).toHaveTitle(/.+/);")

    # Empty scenario: add a basic assertion
    if not step_lines:
        step_lines.append("  await expect(page).toHaveTitle(/.+/);")

    steps_str = "\n".join(step_lines)

    # Fill template
    content = template
    content = content.replace('{{TEST_NAME}}', name)
    content = content.replace('  {{STEPS}}', steps_str)

    filename = scenario_to_filename(name)
    filepath = os.path.join(output_dir, filename)
    with open(filepath, 'w') as f:
        f.write(content)

    files_written.append(filename)
    print(f"  ✅ {filepath}")

if not files_written:
    print('⚠️  No passing scenarios to generate tests for.', file=sys.stderr)
    sys.exit(0)

print(f"\n✅ Generated {len(files_written)} test file(s) in {output_dir}")
PYEOF
