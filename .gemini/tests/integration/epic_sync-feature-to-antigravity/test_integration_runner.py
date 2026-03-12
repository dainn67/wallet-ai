"""Integration tests for epic sync-feature-to-antigravity.
Wraps the bash test script for pytest discovery."""

import subprocess
import os
import tempfile

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SCRIPT = os.path.join(PROJECT_ROOT, 'scripts', 'pm', 'antigravity-sync.sh')
INTEG_SCRIPT = os.path.join(os.path.dirname(__file__), 'test_integration.sh')


def test_integration_suite():
    """Run the full integration test bash script."""
    result = subprocess.run(
        ['bash', INTEG_SCRIPT],
        capture_output=True, text=True, timeout=120
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Integration tests failed:\n{result.stdout}\n{result.stderr}"


def test_config_script_interface():
    """Script correctly reads config mappings."""
    result = subprocess.run(
        ['python3', '-c', f"""
import json
c = json.load(open('{PROJECT_ROOT}/config/antigravity-sync.json'))
m = c['mappings']
assert m['workflows']['source'] == 'commands/pm', f"workflows source: {{m['workflows']['source']}}"
assert m['workflows']['target'] == 'antigravity/workflows'
assert m['rules']['source'] == 'rules'
assert m['rules']['target'] == 'antigravity/rules'
assert 'antigravity-sync' in c.get('skip_patterns', [])
print('OK')
"""],
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"Config interface check failed:\n{result.stderr}"


def test_tier_comment_matches_model_tiers():
    """Transformed workflow tier comment matches model-tiers.json."""
    with tempfile.NamedTemporaryFile(suffix='.md', delete=False) as tmp:
        tmp_path = tmp.name

    try:
        result = subprocess.run(
            ['bash', SCRIPT, 'transform-workflow',
             os.path.join(PROJECT_ROOT, 'commands', 'pm', 'status.md'),
             tmp_path],
            capture_output=True, text=True, timeout=30
        )
        assert result.returncode == 0, f"transform failed:\n{result.stderr}"

        # Read transformed file
        with open(tmp_path) as f:
            content = f.read()

        # Get expected tier
        import json
        with open(os.path.join(PROJECT_ROOT, 'config', 'model-tiers.json')) as f:
            tiers = json.load(f)
        expected = tiers.get('commands', {}).get('status', 'medium')

        assert f'# tier: {expected}' in content, \
            f"Expected '# tier: {expected}' in output, got:\n{content[:200]}"
    finally:
        os.unlink(tmp_path)


def test_transform_pipeline_frontmatter():
    """Full transform pipeline correctly modifies frontmatter."""
    with tempfile.NamedTemporaryFile(suffix='.md', delete=False) as tmp:
        tmp_path = tmp.name

    try:
        result = subprocess.run(
            ['bash', SCRIPT, 'transform-workflow',
             os.path.join(PROJECT_ROOT, 'commands', 'pm', 'epic-start.md'),
             tmp_path],
            capture_output=True, text=True, timeout=30
        )
        assert result.returncode == 0

        with open(tmp_path) as f:
            content = f.read()

        # Removed fields
        lines = content.split('\n')
        for line in lines:
            assert not line.startswith('model:'), "model: field should be removed"
            assert not line.startswith('allowed-tools:'), "allowed-tools: should be removed"

        # Added fields
        assert 'name:' in content, "Missing name: field"
        assert 'description:' in content, "Missing description: field"

        # Variable replacement
        assert '$EPIC_NAME' in content, "ARGUMENTS should be replaced with EPIC_NAME"

        # Content preserved
        assert 'Epic Start' in content, "Content body should be preserved"
    finally:
        os.unlink(tmp_path)


def test_naming_convention():
    """All workflow files follow pm-{name}.md naming convention."""
    wf_dir = os.path.join(PROJECT_ROOT, 'antigravity', 'workflows')
    for f in os.listdir(wf_dir):
        if f.endswith('.md'):
            assert f.startswith('pm-'), f"Workflow file {f} doesn't follow pm-{{name}}.md naming"


def test_rule_naming_convention():
    """All rule files follow ccpm-{name}.md naming convention."""
    rules_dir = os.path.join(PROJECT_ROOT, 'antigravity', 'rules')
    for f in os.listdir(rules_dir):
        if f.endswith('.md'):
            assert f.startswith('ccpm-'), f"Rule file {f} doesn't follow ccpm-{{name}}.md naming"


def test_idempotent_state():
    """Current state shows 0 gaps (fully synced)."""
    result = subprocess.run(
        ['bash', SCRIPT, 'detect'],
        capture_output=True, text=True, timeout=30
    )
    assert result.returncode == 0
    assert 'Total: 0 gaps' in result.stdout, \
        f"Expected 0 gaps, got:\n{result.stdout}"


def test_existing_unit_tests_pass():
    """The existing unit test suite passes."""
    test_file = os.path.join(PROJECT_ROOT, 'tests', 'test-antigravity-sync.sh')
    result = subprocess.run(
        ['bash', test_file],
        capture_output=True, text=True, timeout=120
    )
    assert result.returncode == 0, f"Unit tests failed:\n{result.stdout}\n{result.stderr}"
