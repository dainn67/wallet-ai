"""
Smoke Tests — Epic: issue-new (Light Path)
Phase B Verification: Tier 1

Tests structural integrity and basic functionality of all Light Path deliverables.
"""

import subprocess
import os
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)
))))


def run(cmd, **kwargs):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          cwd=PROJECT_ROOT, **kwargs)


# ── New files exist and are executable ──

class TestNewFilesExist:
    """All 6 new files created by the epic exist."""

    def test_issue_new_command_exists(self):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, "commands/pm/issue-new.md"))

    def test_issue_new_sync_script_exists(self):
        path = os.path.join(PROJECT_ROOT, "scripts/pm/issue-new-sync.sh")
        assert os.path.isfile(path)
        assert os.access(path, os.X_OK), "issue-new-sync.sh is not executable"

    def test_debug_journal_rules_exist(self):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, "rules/debug-journal.md"))

    def test_knowledge_extract_script_exists(self):
        path = os.path.join(PROJECT_ROOT, "scripts/knowledge-extract.sh")
        assert os.path.isfile(path)
        assert os.access(path, os.X_OK), "knowledge-extract.sh is not executable"

    def test_debug_journal_archive_script_exists(self):
        path = os.path.join(PROJECT_ROOT, "scripts/debug-journal-archive.sh")
        assert os.path.isfile(path)
        assert os.access(path, os.X_OK), "debug-journal-archive.sh is not executable"

    def test_save_debug_journal_script_exists(self):
        path = os.path.join(PROJECT_ROOT, "scripts/save-debug-journal.sh")
        assert os.path.isfile(path)
        assert os.access(path, os.X_OK), "save-debug-journal.sh is not executable"


# ── Modified files have expected changes ──

class TestModifiedFiles:
    """3 modified files have expected Light Path enhancements."""

    def test_issue_start_has_light_path_support(self):
        result = run("grep -c 'IS_LIGHT_PATH\\|source:issue-new' commands/pm/issue-start.md")
        count = int(result.stdout.strip())
        assert count >= 10, f"Expected >= 10 Light Path refs in issue-start.md, found {count}"

    def test_issue_start_has_branch_strategy(self):
        result = run("grep -c 'branch-strategy' commands/pm/issue-start.md")
        count = int(result.stdout.strip())
        assert count >= 2, f"Expected >= 2 branch-strategy refs, found {count}"

    def test_issue_complete_has_knowledge_extract(self):
        result = run("grep -c 'knowledge.extract\\|knowledge-extract' commands/pm/issue-complete.md")
        count = int(result.stdout.strip())
        assert count >= 1, "knowledge-extract not found in issue-complete.md"

    def test_issue_complete_has_journal_archive(self):
        result = run("grep -c 'debug-journal-archive\\|journal.archive' commands/pm/issue-complete.md")
        count = int(result.stdout.strip())
        assert count >= 1, "journal-archive not found in issue-complete.md"

    def test_pretask_hook_has_journal_snapshot(self):
        result = run("grep -c 'save-debug-journal' hooks/pre-task.sh")
        count = int(result.stdout.strip())
        assert count >= 1, "save-debug-journal not found in pre-task.sh"


# ── Syntax checks ──

class TestScriptSyntax:
    """All bash scripts pass syntax checking."""

    @pytest.mark.parametrize("script", [
        "scripts/pm/issue-new-sync.sh",
        "scripts/knowledge-extract.sh",
        "scripts/debug-journal-archive.sh",
        "scripts/save-debug-journal.sh",
    ])
    def test_bash_syntax(self, script):
        result = run(f"bash -n {script}")
        assert result.returncode == 0, f"Syntax error in {script}: {result.stderr}"


# ── Content quality checks ──

class TestCommandContent:
    """Command files have expected content structure."""

    def test_issue_new_has_investigation_pipeline(self):
        """issue-new.md has 6-step investigation pipeline."""
        result = run("grep -c 'Step\\|step' commands/pm/issue-new.md")
        count = int(result.stdout.strip())
        assert count >= 6, f"Expected >= 6 step references, found {count}"

    def test_issue_new_has_complexity_assessment(self):
        """issue-new.md includes LOW/MEDIUM/HIGH complexity assessment."""
        for level in ["LOW", "MEDIUM", "HIGH"]:
            result = run(f"grep -c '{level}' commands/pm/issue-new.md")
            count = int(result.stdout.strip())
            assert count >= 1, f"{level} not found in issue-new.md"

    def test_issue_new_has_scan_cap(self):
        """issue-new.md enforces 30-file scan cap (NFR-1)."""
        result = run("grep -c '30' commands/pm/issue-new.md")
        count = int(result.stdout.strip())
        assert count >= 1, "30-file cap not found in issue-new.md"

    def test_debug_journal_rules_has_modes(self):
        """debug-journal.md defines 3 journal modes."""
        for mode in ["auto", "semi-auto", "manual"]:
            result = run(f"grep -ci '{mode}' rules/debug-journal.md")
            count = int(result.stdout.strip())
            assert count >= 1, f"Mode '{mode}' not found in debug-journal.md"

    def test_debug_journal_rules_has_location(self):
        """debug-journal.md specifies sessions/ location."""
        result = run("grep -c 'sessions/' rules/debug-journal.md")
        count = int(result.stdout.strip())
        assert count >= 1, "sessions/ location not found in debug-journal.md"


# ── Backward compatibility ──

class TestBackwardCompat:
    """Existing commands preserve backward compatibility (NFR-2)."""

    def test_issue_start_preserves_worktree_refs(self):
        """issue-start.md still has worktree references for epic workflow."""
        result = run("grep -c 'worktree' commands/pm/issue-start.md")
        count = int(result.stdout.strip())
        assert count >= 5, f"Expected >= 5 worktree refs (backward compat), found {count}"

    def test_issue_complete_preserves_skillbook_refs(self):
        """issue-complete.md still has skillbook references."""
        result = run("grep -c 'skillbook' commands/pm/issue-complete.md")
        count = int(result.stdout.strip())
        assert count >= 3, f"Expected >= 3 skillbook refs (backward compat), found {count}"

    def test_lifecycle_integration_tests_pass(self):
        """Existing 39-test lifecycle integration suite still passes."""
        result = run("bash tests/test-lifecycle-integration.sh", timeout=120)
        assert result.returncode == 0, (
            f"Lifecycle tests failed:\n{result.stdout[-2000:]}\n{result.stderr[-500:]}"
        )


# ── .gitignore ──

class TestGitignore:
    """.gitignore properly configured."""

    def test_sessions_in_gitignore(self):
        result = run("grep -c 'sessions' .gitignore")
        count = int(result.stdout.strip())
        assert count >= 1, "sessions/ not in .gitignore"


# ── Sync script argument handling ──

class TestSyncScriptArgs:
    """issue-new-sync.sh handles arguments correctly."""

    def test_missing_args_exits_with_error(self):
        result = run("bash scripts/pm/issue-new-sync.sh create 2>&1; echo $?")
        lines = result.stdout.strip().split('\n')
        exit_code = lines[-1]
        assert exit_code == "1", f"Expected exit code 1, got {exit_code}"

    def test_nonexistent_body_file_exits_with_error(self):
        result = run('bash scripts/pm/issue-new-sync.sh create "Test" /tmp/nonexistent-ccpm-test-file.md 2>&1; echo $?')
        lines = result.stdout.strip().split('\n')
        exit_code = lines[-1]
        assert exit_code == "1", f"Expected exit code 1, got {exit_code}"
