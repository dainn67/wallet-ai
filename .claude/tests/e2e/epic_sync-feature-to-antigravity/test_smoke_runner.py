"""Smoke tests for epic sync-feature-to-antigravity.
Wraps the bash test script for pytest discovery."""

import subprocess
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SCRIPT = os.path.join(PROJECT_ROOT, 'scripts', 'pm', 'antigravity-sync.sh')
SMOKE_SCRIPT = os.path.join(os.path.dirname(__file__), 'test_smoke.sh')


def test_smoke_suite():
    """Run the full smoke test bash script."""
    result = subprocess.run(
        ['bash', SMOKE_SCRIPT],
        capture_output=True, text=True, timeout=120
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Smoke tests failed:\n{result.stdout}\n{result.stderr}"


def test_config_valid_json():
    """Config file is valid JSON."""
    result = subprocess.run(
        ['jq', '.', os.path.join(PROJECT_ROOT, 'config', 'antigravity-sync.json')],
        capture_output=True, text=True
    )
    assert result.returncode == 0, "config/antigravity-sync.json is not valid JSON"


def test_model_tiers_has_entry():
    """Model tiers contains antigravity-sync entry."""
    result = subprocess.run(
        ['jq', '-r', '.commands["antigravity-sync"]',
         os.path.join(PROJECT_ROOT, 'config', 'model-tiers.json')],
        capture_output=True, text=True
    )
    assert result.stdout.strip() == 'medium', \
        f"Expected 'medium', got '{result.stdout.strip()}'"


def test_script_executable():
    """Sync script exists and is executable."""
    assert os.path.isfile(SCRIPT), "scripts/pm/antigravity-sync.sh not found"
    assert os.access(SCRIPT, os.X_OK), "scripts/pm/antigravity-sync.sh not executable"


def test_command_entry_point():
    """Command file has model: in frontmatter."""
    cmd_file = os.path.join(PROJECT_ROOT, 'commands', 'pm', 'antigravity-sync.md')
    assert os.path.isfile(cmd_file), "commands/pm/antigravity-sync.md not found"
    with open(cmd_file) as f:
        content = f.read()
    assert 'model:' in content, "Command file missing model: in frontmatter"


def test_detect_runs_without_errors():
    """Gap detection runs successfully."""
    result = subprocess.run(
        ['bash', SCRIPT, 'detect'],
        capture_output=True, text=True, timeout=30
    )
    assert result.returncode == 0, f"detect failed:\n{result.stdout}\n{result.stderr}"
    assert 'Total:' in result.stdout, "detect output missing Total: line"


def test_workflow_format_consistency():
    """All workflows use unified format (no old steps: YAML)."""
    wf_dir = os.path.join(PROJECT_ROOT, 'antigravity', 'workflows')
    old_format = []
    for f in os.listdir(wf_dir):
        if f.startswith('pm-') and f.endswith('.md'):
            path = os.path.join(wf_dir, f)
            with open(path) as fh:
                if '  steps:' in fh.read():
                    old_format.append(f)
    assert len(old_format) == 0, f"Files with old steps: format: {old_format}"


def test_tech_context_updated():
    """Tech context contains Antigravity Sync section."""
    tc = os.path.join(PROJECT_ROOT, '.claude', 'context', 'tech-context.md')
    if os.path.isfile(tc):
        with open(tc) as f:
            content = f.read().lower()
        assert 'antigravity' in content and 'sync' in content, \
            "tech-context.md missing Antigravity Sync section"
