#!/bin/bash
# Health Score Calculator — calculates weighted health score from web inspection results
# Usage: echo $INPUT_JSON | bash scripts/qa/health-score.sh
# Input: JSON with inspection results (console_errors, broken_links, total_links, etc.)
# Output: JSON with total score, per-category breakdown
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/web-qa.json"

if [ ! -f "$CONFIG_FILE" ]; then
  printf '{"success":false,"error":"Config not found: %s","data":null}\n' "$CONFIG_FILE"
  exit 1
fi

# Read JSON input from stdin or file argument
if [ "${1:-}" = "-" ] || [ -z "${1:-}" ]; then
  INPUT_JSON=$(cat)
else
  INPUT_JSON=$(cat "$1")
fi

if [ -z "$INPUT_JSON" ]; then
  printf '{"success":false,"error":"No input JSON provided","data":null}\n'
  exit 1
fi

python3 - "$INPUT_JSON" "$CONFIG_FILE" <<'PYEOF'
import json
import sys

input_json = sys.argv[1]
config_file = sys.argv[2]

# Parse inputs
try:
    data = json.loads(input_json)
except json.JSONDecodeError as e:
    print(json.dumps({"success": False, "error": f"Invalid input JSON: {e}", "data": None}))
    sys.exit(1)

try:
    with open(config_file) as f:
        config = json.load(f)
    weights = config.get("health_weights", {
        "console": 15, "links": 10, "visual": 10, "functional": 20,
        "ux": 15, "performance": 10, "content": 5, "accessibility": 15
    })
except Exception as e:
    print(json.dumps({"success": False, "error": f"Failed to read config: {e}", "data": None}))
    sys.exit(1)

categories = {}

# --- Console (15%): 100 - (error_count * 15), warnings = 5 each ---
if "console_errors" in data or "console_warnings" in data:
    errors = data.get("console_errors", 0)
    # Support both flat count and array format from ccpm-browse console command
    if isinstance(errors, list):
        errors = len(errors)
    warnings = data.get("console_warnings", 0)
    if isinstance(warnings, list):
        warnings = len(warnings)
    score = max(0, 100 - (errors * 15) - (warnings * 5))
    issues = []
    if errors > 0:
        issues.append(f"{errors} console error(s)")
    if warnings > 0:
        issues.append(f"{warnings} console warning(s)")
    categories["console"] = {"score": score, "weight": weights.get("console", 15), "issues": issues}

# --- Links (10%): (total - broken) / total * 100 ---
if "broken_links" in data or "total_links" in data:
    total = data.get("total_links", 0)
    broken = data.get("broken_links", 0)
    if isinstance(broken, list):
        broken = len(broken)
    if total == 0:
        score = 100
    else:
        score = max(0, round((total - broken) / total * 100))
    issues = [f"{broken} broken link(s)"] if broken > 0 else []
    categories["links"] = {"score": score, "weight": weights.get("links", 10), "issues": issues}

# --- Visual (10%): CLS-based ---
if "cls" in data:
    cls = data.get("cls", 0)
    if cls < 0.1:
        score = 100
    elif cls < 0.25:
        score = 50
    else:
        score = 0
    issues = [f"CLS={cls}"] if cls >= 0.1 else []
    categories["visual"] = {"score": score, "weight": weights.get("visual", 10), "issues": issues}

# --- Functional (20%): 100 - (js_errors * 20) ---
if "js_errors" in data or "console_errors" in data:
    js_errors = data.get("js_errors", data.get("console_errors", 0))
    if isinstance(js_errors, list):
        js_errors = len(js_errors)
    score = max(0, 100 - (js_errors * 20))
    issues = [f"{js_errors} JS error(s)"] if js_errors > 0 else []
    categories["functional"] = {"score": score, "weight": weights.get("functional", 20), "issues": issues}

# --- UX (15%): forms_with_labels / total_forms * 100 ---
if "forms_with_labels" in data or "total_forms" in data:
    total_forms = data.get("total_forms", 0)
    forms_with_labels = data.get("forms_with_labels", 0)
    # Support ccpm-browse forms command format
    if "forms" in data and isinstance(data["forms"], list):
        total_forms = len(data["forms"])
        forms_with_labels = sum(1 for f in data["forms"] if f.get("has_labels", False))
    if total_forms == 0:
        score = 100
    else:
        score = max(0, round(forms_with_labels / total_forms * 100))
    issues = [f"{total_forms - forms_with_labels} form(s) missing labels"] if total_forms > forms_with_labels else []
    categories["ux"] = {"score": score, "weight": weights.get("ux", 15), "issues": issues}

# --- Performance (10%): load time based ---
if "load_time" in data:
    load_time = data.get("load_time", 0)
    if load_time < 1:
        score = 100
    elif load_time < 2:
        score = 80
    elif load_time < 3:
        score = 60
    elif load_time < 5:
        score = 40
    else:
        score = 20
    issues = [f"Load time: {load_time}s"] if load_time >= 2 else []
    categories["performance"] = {"score": score, "weight": weights.get("performance", 10), "issues": issues}

# --- Content (5%): images with alt text ---
if "images_without_alt" in data or "total_images" in data:
    total_images = data.get("total_images", 0)
    images_without_alt = data.get("images_without_alt", 0)
    if total_images == 0:
        score = 100
    else:
        images_with_alt = total_images - images_without_alt
        score = max(0, round(images_with_alt / total_images * 100))
    issues = [f"{images_without_alt} image(s) missing alt text"] if images_without_alt > 0 else []
    categories["content"] = {"score": score, "weight": weights.get("content", 5), "issues": issues}

# --- Accessibility (15%): composite of ARIA, headings, form labels ---
if "aria_landmarks" in data or "heading_hierarchy" in data or "a11y_errors" in data:
    sub_scores = []
    a11y_issues = []

    aria = data.get("aria_landmarks", None)
    if aria is not None:
        sub_scores.append(100 if aria else 50)
        if not aria:
            a11y_issues.append("Missing ARIA landmarks")

    headings = data.get("heading_hierarchy", None)
    if headings is not None:
        sub_scores.append(100 if headings else 50)
        if not headings:
            a11y_issues.append("Heading hierarchy issues")

    a11y_errors = data.get("a11y_errors", 0)
    if a11y_errors > 0:
        a11y_issues.append(f"{a11y_errors} accessibility error(s)")
        sub_scores.append(max(0, 100 - (a11y_errors * 10)))

    score = round(sum(sub_scores) / len(sub_scores)) if sub_scores else 100
    categories["accessibility"] = {"score": score, "weight": weights.get("accessibility", 15), "issues": a11y_issues}

# --- Calculate weighted total (redistribute weights for unassessed categories) ---
assessed_weight_sum = sum(cat["weight"] for cat in categories.values())
not_assessed = [k for k in weights if k not in categories]

if assessed_weight_sum == 0:
    total_score = 0
else:
    weighted_sum = sum(cat["score"] * cat["weight"] for cat in categories.values())
    total_score = round(weighted_sum / assessed_weight_sum)

result = {
    "total": total_score,
    "categories": categories,
    "assessed": len(categories),
    "not_assessed": len(not_assessed),
    "not_assessed_list": not_assessed
}

print(json.dumps({"success": True, "error": None, "data": result}))
PYEOF
