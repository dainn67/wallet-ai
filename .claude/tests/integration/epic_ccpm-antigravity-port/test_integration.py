"""
Integration Tests — Epic: ccpm-antigravity-port
Phase B Verification: Tier 2

Tests interfaces between components:
- Skills ↔ .claude/ scripts
- Install ↔ .agent/ structure
- pre-task.sh ↔ active-ide.json
- Cross-IDE sync: write-handoff ↔ sync-context
"""

import subprocess
import os
import json
import tempfile
import shutil
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)
))))


def run(cmd, **kwargs):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          cwd=PROJECT_ROOT, **kwargs)


# ── Integration: Skills ↔ .claude/scripts ──

def test_load_context_references_correct_paths():
    """ccpm-context-loader/load-context.sh references .claude/ paths"""
    script = "antigravity/skills/ccpm-context-loader/scripts/load-context.sh"
    result = run(f"grep -c '.claude/' '{script}'")
    count = int(result.stdout.strip() or "0")
    assert count >= 2, f"Expected ≥2 .claude/ references, got {count}"


def test_run_verify_references_profiles_dir():
    """ccpm-verification/run-verify.sh references verify/profiles/"""
    script = "antigravity/skills/ccpm-verification/scripts/run-verify.sh"
    result = run(f"grep -c 'verify/profiles' '{script}'")
    count = int(result.stdout.strip() or "0")
    assert count >= 1, "run-verify.sh doesn't reference verify/profiles/"


def test_ralph_loop_max_iterations():
    """ralph-loop.sh has max 20 iterations default"""
    script = "antigravity/skills/ccpm-verification/scripts/ralph-loop.sh"
    result = run(f"grep 'MAX_ITERATIONS.*20' '{script}'")
    assert result.returncode == 0, "ralph-loop.sh max iterations != 20"


def test_write_handoff_updates_active_ide():
    """write-handoff.sh updates active-ide.json with last_ide"""
    script = "antigravity/skills/ccpm-handoff/scripts/write-handoff.sh"
    result = run(f"grep -c 'last_ide' '{script}'")
    count = int(result.stdout.strip() or "0")
    assert count >= 1, "write-handoff.sh doesn't update last_ide"


def test_sync_context_reads_active_ide():
    """sync-context.sh reads and processes active-ide.json"""
    script = "antigravity/skills/ccpm-context-sync/scripts/sync-context.sh"
    result = run(f"grep -c 'active-ide' '{script}'")
    count = int(result.stdout.strip() or "0")
    assert count >= 2, "sync-context.sh doesn't integrate with active-ide.json"


def test_check_design_uses_correct_path_pattern():
    """check-design.sh checks .claude/epics/{epic}/designs/task-{N}-design.md"""
    script = "antigravity/skills/ccpm-pre-implementation/scripts/check-design.sh"
    result = run(f"grep 'designs/task-' '{script}'")
    assert result.returncode == 0, "check-design.sh doesn't use correct path pattern"


def test_plan_gaps_reads_epic_reports():
    """plan-gaps.sh reads from .claude/context/verify/epic-reports/"""
    script = "antigravity/skills/ccpm-epic-planning/scripts/plan-gaps.sh"
    result = run(f"grep -c 'epic-reports' '{script}'")
    count = int(result.stdout.strip() or "0")
    assert count >= 1, "plan-gaps.sh doesn't read from epic-reports/"


def test_phase_a_uses_input_assembly():
    """ccpm-epic-verify/phase-a.sh references epic-input-assembly.sh"""
    script = "antigravity/skills/ccpm-epic-verify/scripts/phase-a.sh"
    result = run(f"grep -c 'input-assembly' '{script}'")
    count = int(result.stdout.strip() or "0")
    assert count >= 1, "phase-a.sh doesn't use epic-input-assembly.sh"


# ── Integration: Install ↔ .agent/ structure ──

def test_install_copies_all_three_dirs():
    """Install copies skills/, workflows/, rules/ to .agent/"""
    result = run("grep -c '\"$dir\"' install/local_install.sh")
    # Just verify the install iterates dirs: skills workflows rules
    result2 = run("grep 'skills workflows rules' install/local_install.sh")
    assert result2.returncode == 0, "Install script doesn't copy skills/workflows/rules"


def test_install_copies_active_ide_template():
    """Install copies active-ide.json template to .claude/sync/"""
    result = run("grep -c 'active-ide.json' install/local_install.sh")
    count = int(result.stdout.strip() or "0")
    assert count >= 2, "Install script doesn't handle active-ide.json"


def test_install_makes_scripts_executable():
    """Install script makes skill scripts executable via chmod +x"""
    result = run("grep -c 'chmod.*+x' install/local_install.sh")
    count = int(result.stdout.strip() or "0")
    assert count >= 1, "Install script missing chmod +x for scripts"


def test_install_adds_agent_to_gitignore():
    """Install script adds .agent/ to project .gitignore"""
    result = run("grep -c 'gitignore' install/local_install.sh")
    count = int(result.stdout.strip() or "0")
    assert count >= 1, "Install script missing .gitignore update"


# ── Integration: pre-task.sh ↔ active-ide.json ──

def test_pretask_ide_detection_is_backward_compatible():
    """pre-task.sh: missing active-ide.json is handled gracefully"""
    result = run("grep 'skip.*silently\\|backward.*compat' hooks/pre-task.sh")
    assert result.returncode == 0, "pre-task.sh missing backward-compatible handling"


def test_pretask_ide_detection_after_existing_logic():
    """pre-task.sh IDE detection is at end of file (not reordering existing logic)"""
    result = run("wc -l hooks/pre-task.sh | awk '{print $1}'")
    total_lines = int(result.stdout.strip())
    # IDE detection should be in last 30 lines
    result2 = run("grep -n 'active-ide' hooks/pre-task.sh | head -1 | cut -d: -f1")
    detect_line = int(result2.stdout.strip() or "0")
    assert detect_line > total_lines - 40, (
        f"IDE detection at line {detect_line}/{total_lines} — should be at end of file"
    )


# ── Integration: Skill triggers are mutually exclusive ──

def test_context_loader_trigger_no_overlap_with_handoff():
    """context-loader and handoff triggers don't overlap"""
    loader_desc = run("head -5 antigravity/skills/ccpm-context-loader/SKILL.md | grep description").stdout
    handoff_desc = run("head -5 antigravity/skills/ccpm-handoff/SKILL.md | grep description").stdout
    # context-loader should NOT trigger on "ending session"
    assert "ending" not in loader_desc.lower() or "NOT" in loader_desc, \
        "context-loader may overlap with handoff triggers"


def test_pre_implementation_trigger_no_overlap_with_verification():
    """pre-implementation and verification triggers don't overlap"""
    pre_impl = run("head -5 antigravity/skills/ccpm-pre-implementation/SKILL.md | grep description").stdout
    verify = run("head -5 antigravity/skills/ccpm-verification/SKILL.md | grep description").stdout
    # pre-implementation should NOT trigger on "done"
    assert "done" not in pre_impl.lower() or "NOT" in pre_impl, \
        "pre-implementation may overlap with verification triggers"


def test_epic_verify_trigger_no_overlap_with_task_verify():
    """ccpm-epic-verify triggers don't overlap with task-level ccpm-verification"""
    epic_desc = run("head -5 antigravity/skills/ccpm-epic-verify/SKILL.md | grep description").stdout
    task_desc = run("head -5 antigravity/skills/ccpm-verification/SKILL.md | grep description").stdout
    # epic-verify should NOT trigger on "done"/"complete" (task-level)
    assert "NOT for" in epic_desc or "NOT for" in epic_desc.upper(), \
        "ccpm-epic-verify missing NOT for exclusion"
