"""Pytest runner for build-orchestrator-fidelity smoke tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def test_smoke_01_delegation_protocol():
    """Verify delegation protocol rule exists with all required sections."""
    result = subprocess.run(
        ["bash", "tests/e2e/epic_build-orchestrator-fidelity/test_smoke_01_delegation_protocol.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=30,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Smoke test 01 failed:\n{result.stdout}\n{result.stderr}"


def test_smoke_02_build_md_sections():
    """Verify build.md contains all required new sections and is within line limit."""
    result = subprocess.run(
        ["bash", "tests/e2e/epic_build-orchestrator-fidelity/test_smoke_02_build_md_sections.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=30,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Smoke test 02 failed:\n{result.stdout}\n{result.stderr}"
