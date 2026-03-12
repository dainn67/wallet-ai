"""
Smoke Tests — Epic: ccpm-antigravity-port
Phase B Verification: Tier 1

Tests full user flows for Antigravity adapter deliverables.
"""

import subprocess
import os
import json
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)
))))


def run(cmd, **kwargs):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          cwd=PROJECT_ROOT, **kwargs)


# ── Tier 1 Smoke: Structural integrity ──

def test_28_workflows_exist():
    """At least 28 workflow files exist in antigravity/workflows/"""
    result = run("ls antigravity/workflows/*.md 2>/dev/null | wc -l")
    count = int(result.stdout.strip())
    assert count >= 28, f"Expected >= 28 workflows, found {count}"


def test_7_skills_exist():
    """All 7 SKILL.md files exist in antigravity/skills/"""
    result = run("ls antigravity/skills/*/SKILL.md 2>/dev/null | wc -l")
    count = int(result.stdout.strip())
    assert count == 7, f"Expected 7 skills, found {count}"


def test_6_rules_exist():
    """At least 6 rule files exist in antigravity/rules/"""
    result = run("ls antigravity/rules/*.md 2>/dev/null | wc -l")
    count = int(result.stdout.strip())
    assert count >= 6, f"Expected >= 6 rules, found {count}"


def test_readme_exists():
    """antigravity/README.md exists"""
    assert os.path.isfile(os.path.join(PROJECT_ROOT, "antigravity", "README.md"))


def test_active_ide_template_has_7_fields():
    """active-ide.json template has all 7 required fields"""
    template_path = os.path.join(PROJECT_ROOT, "antigravity", "templates", "active-ide.json")
    assert os.path.isfile(template_path), "Template file missing"
    with open(template_path) as f:
        data = json.load(f)
    required_fields = ["last_ide", "last_session_end", "last_action",
                       "pending_handoff", "open_tasks", "active_epic", "verify_state"]
    for field in required_fields:
        assert field in data, f"Missing field: {field}"


def test_all_scripts_executable():
    """All 11 skill scripts are executable"""
    result = run("find antigravity/skills -name '*.sh' | wc -l")
    total = int(result.stdout.strip())
    result2 = run("find antigravity/skills -name '*.sh' -perm +111 | wc -l")
    executable = int(result2.stdout.strip())
    assert total > 0, "No scripts found"
    assert executable == total, f"Only {executable}/{total} scripts are executable"


def test_workflows_have_description_frontmatter():
    """All 28 workflows have valid description: field in frontmatter"""
    result = run(
        "for f in antigravity/workflows/*.md; do "
        "  grep -q '^description:' \"$f\" || echo \"MISSING: $f\"; "
        "done"
    )
    missing = result.stdout.strip()
    assert missing == "", f"Missing description frontmatter in:\n{missing}"


def test_gitignore_has_agent():
    """.gitignore includes .agent/ entry"""
    result = run("grep -c '^.agent/$' .gitignore 2>/dev/null; true")
    count = int(result.stdout.strip())
    assert count >= 1, ".agent/ not found in .gitignore"


def test_install_script_has_antigravity_flag():
    """install/local_install.sh has --antigravity handler"""
    result = run("grep -c 'antigravity' install/local_install.sh 2>/dev/null || echo 0")
    count = int(result.stdout.strip())
    assert count > 0, "--antigravity flag missing from install script"


def test_install_error_without_gemini_base():
    """--antigravity without .gemini/ produces clear error"""
    result = run("grep -c 'CCPM base required' install/local_install.sh 2>/dev/null || echo 0")
    count = int(result.stdout.strip())
    assert count >= 1, "Missing CCPM base required error message"


def test_pretask_hook_has_ide_detection():
    """pre-task.sh has IDE switch detection block"""
    result = run("grep -c 'active-ide' hooks/pre-task.sh 2>/dev/null || echo 0")
    count = int(result.stdout.strip())
    assert count >= 1, "IDE detection missing from pre-task.sh"


def test_full_integration_test_suite_passes():
    """Existing 57-test integration suite passes (full smoke validation)"""
    result = run("bash tests/test-antigravity-integration.sh", timeout=120)
    assert result.returncode == 0, (
        f"Integration tests failed:\n{result.stdout[-2000:]}\n{result.stderr[-500:]}"
    )
