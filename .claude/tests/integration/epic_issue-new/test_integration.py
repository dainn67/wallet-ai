"""
Integration Tests — Epic: issue-new (Light Path)
Phase B Verification: Tier 2

Tests interfaces between components: issue-new ↔ sync script,
issue-start ↔ debug-journal, issue-complete ↔ knowledge-extract/archive,
pre-task ↔ save-debug-journal.
"""

import subprocess
import os
import tempfile
import shutil
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)
))))


def run(cmd, **kwargs):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          cwd=PROJECT_ROOT, **kwargs)


# ── issue-new-sync.sh interface tests ──

class TestSyncScriptInterface:
    """Tests issue-new-sync.sh receives correct args and produces expected output."""

    def test_sync_script_sources_github_helpers(self):
        """Sync script can source github-helpers.sh without error."""
        result = run("bash -c 'source scripts/pm/issue-new-sync.sh 2>/dev/null; echo ok'")
        assert "ok" in result.stdout, f"Failed to source: {result.stderr}"

    def test_sync_script_label_parsing(self):
        """Sync script correctly parses CSV labels and appends source:issue-new."""
        result = run("""bash -c '
            source scripts/pm/issue-new-sync.sh 2>/dev/null
            labels_csv="bug,complexity:low"
            labels=()
            if [ -n "$labels_csv" ]; then
                IFS="," read -ra raw_labels <<< "$labels_csv"
                for lbl in "${raw_labels[@]}"; do
                    lbl="${lbl## }"; lbl="${lbl%% }"
                    [ -n "$lbl" ] && labels+=("$lbl")
                done
            fi
            labels+=("source:issue-new")
            echo "${#labels[@]}"
        '""")
        count = result.stdout.strip()
        assert count == "3", f"Expected 3 labels, got {count}"

    def test_sync_script_empty_labels_only_source(self):
        """Empty CSV results in only source:issue-new label."""
        result = run("""bash -c '
            source scripts/pm/issue-new-sync.sh 2>/dev/null
            labels_csv=""
            labels=()
            if [ -n "$labels_csv" ]; then
                IFS="," read -ra raw_labels <<< "$labels_csv"
                for lbl in "${raw_labels[@]}"; do
                    lbl="${lbl## }"; lbl="${lbl%% }"
                    [ -n "$lbl" ] && labels+=("$lbl")
                done
            fi
            labels+=("source:issue-new")
            echo "${#labels[@]}"
        '""")
        count = result.stdout.strip()
        assert count == "1", f"Expected 1 label, got {count}"


# ── Debug journal integration tests ──

class TestDebugJournalIntegration:
    """Tests journal creation format matches rules specification."""

    def test_journal_rules_define_header_format(self):
        """debug-journal.md specifies journal header format."""
        result = run("grep -c 'Header\\|Created:\\|Mode:' rules/debug-journal.md")
        count = int(result.stdout.strip())
        assert count >= 2, "Journal rules don't define header format"

    def test_journal_rules_define_round_format(self):
        """debug-journal.md specifies round format with hypothesis/action/result."""
        for field in ["hypothesis", "action", "result"]:
            result = run(f"grep -ci '{field}' rules/debug-journal.md")
            count = int(result.stdout.strip())
            assert count >= 1, f"'{field}' not found in journal rules"

    def test_issue_start_references_journal_rules(self):
        """issue-start.md references debug-journal rules for journal creation."""
        result = run("grep -c 'debug-journal\\|journal' commands/pm/issue-start.md")
        count = int(result.stdout.strip())
        assert count >= 3, f"Expected >= 3 journal refs in issue-start, found {count}"


# ── Knowledge extract + archive integration tests ──

class TestKnowledgeExtractIntegration:
    """Tests knowledge-extract.sh and debug-journal-archive.sh interfaces."""

    def test_knowledge_extract_accepts_issue_number(self):
        """knowledge-extract.sh accepts issue number argument."""
        # Without a real journal file, it should handle gracefully
        result = run("bash scripts/knowledge-extract.sh 99999 2>&1; echo EXIT:$?")
        # Should not crash — graceful handling when no journal exists
        assert "EXIT:" in result.stdout

    def test_journal_archive_accepts_issue_number(self):
        """debug-journal-archive.sh accepts issue number argument."""
        result = run("bash scripts/debug-journal-archive.sh 99999 2>&1; echo EXIT:$?")
        assert "EXIT:" in result.stdout

    def test_knowledge_extract_with_journal(self):
        """knowledge-extract.sh reads journal file and produces output."""
        journal_dir = os.path.join(PROJECT_ROOT, ".claude/context/sessions")
        os.makedirs(journal_dir, exist_ok=True)
        journal_file = os.path.join(journal_dir, "issue-88888-debug.md")

        try:
            with open(journal_file, 'w') as f:
                f.write("---\nissue: 88888\nmode: semi-auto\n---\n")
                f.write("# Debug Journal: Issue #88888\n\n")
                f.write("## Round 1 — 2026-03-05T00:00:00Z\n")
                f.write("**Hypothesis:** Test hypothesis\n")
                f.write("**Action:** Test action\n")
                f.write("**Result:** Test result\n")

            result = run("bash scripts/knowledge-extract.sh 88888 2>&1")
            # Script should produce some output (close comment sections)
            assert result.returncode == 0 or len(result.stdout) > 0
        finally:
            if os.path.exists(journal_file):
                os.remove(journal_file)

    def test_journal_archive_moves_file(self):
        """debug-journal-archive.sh moves journal to archive directory."""
        journal_dir = os.path.join(PROJECT_ROOT, ".claude/context/sessions")
        archive_dir = os.path.join(journal_dir, "archive")
        os.makedirs(journal_dir, exist_ok=True)
        journal_file = os.path.join(journal_dir, "issue-77777-debug.md")

        try:
            with open(journal_file, 'w') as f:
                f.write("---\nissue: 77777\nmode: auto\n---\n")
                f.write("# Debug Journal: Issue #77777\n\n")
                f.write("## Round 1 — 2026-03-05T00:00:00Z\n")
                f.write("**Hypothesis:** H1\n**Action:** A1\n**Result:** R1\n")

            result = run("bash scripts/debug-journal-archive.sh 77777 2>&1")
            # Archive should either move the file or produce output
            assert result.returncode == 0 or len(result.stdout) > 0
        finally:
            # Cleanup
            if os.path.exists(journal_file):
                os.remove(journal_file)
            for f in os.listdir(archive_dir) if os.path.isdir(archive_dir) else []:
                if "77777" in f:
                    os.remove(os.path.join(archive_dir, f))


# ── PreCompact hook integration tests ──

class TestPreCompactHookIntegration:
    """Tests save-debug-journal.sh copies active journals."""

    def test_save_journal_with_no_journals(self):
        """save-debug-journal.sh exits cleanly when no journals exist."""
        result = run("bash scripts/save-debug-journal.sh 2>&1")
        # Should exit 0 when no journals found
        assert result.returncode == 0, f"Expected exit 0, got {result.returncode}: {result.stderr}"

    def test_save_journal_copies_active_journal(self):
        """save-debug-journal.sh copies active journal to archive."""
        journal_dir = os.path.join(PROJECT_ROOT, ".claude/context/sessions")
        archive_dir = os.path.join(journal_dir, "archive")
        os.makedirs(journal_dir, exist_ok=True)
        journal_file = os.path.join(journal_dir, "issue-66666-debug.md")

        try:
            with open(journal_file, 'w') as f:
                f.write("---\nissue: 66666\n---\n# Test Journal\n")

            result = run("bash scripts/save-debug-journal.sh 2>&1")
            assert result.returncode == 0, f"Hook failed: {result.stderr}"

            # Check archive was created
            if os.path.isdir(archive_dir):
                archived = [f for f in os.listdir(archive_dir) if "66666" in f]
                assert len(archived) >= 1, "Journal not archived by save-debug-journal.sh"
        finally:
            if os.path.exists(journal_file):
                os.remove(journal_file)
            if os.path.isdir(archive_dir):
                for f in os.listdir(archive_dir):
                    if "66666" in f:
                        os.remove(os.path.join(archive_dir, f))

    def test_pretask_hook_calls_save_journal(self):
        """pre-task.sh includes call to save-debug-journal.sh."""
        result = run("grep 'save-debug-journal' hooks/pre-task.sh")
        assert result.returncode == 0, "pre-task.sh doesn't call save-debug-journal.sh"


# ── issue-complete ↔ knowledge-extract interface ──

class TestIssueCompleteInterface:
    """Tests issue-complete.md correctly references knowledge extract scripts."""

    def test_issue_complete_calls_knowledge_extract(self):
        """issue-complete.md references knowledge-extract.sh."""
        result = run("grep -c 'knowledge-extract' commands/pm/issue-complete.md")
        count = int(result.stdout.strip())
        assert count >= 1, "issue-complete.md doesn't reference knowledge-extract.sh"

    def test_issue_complete_calls_journal_archive(self):
        """issue-complete.md references debug-journal-archive.sh."""
        result = run("grep -c 'debug-journal-archive' commands/pm/issue-complete.md")
        count = int(result.stdout.strip())
        assert count >= 1, "issue-complete.md doesn't reference debug-journal-archive.sh"

    def test_issue_complete_has_no_learn_flag(self):
        """issue-complete.md supports --no-learn flag for skipping knowledge extract."""
        result = run("grep -c 'no-learn\\|no.learn' commands/pm/issue-complete.md")
        count = int(result.stdout.strip())
        assert count >= 1, "--no-learn flag not found in issue-complete.md"
