"""Pytest wrapper for epic-autopilot smoke tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

def test_smoke_epic_autopilot():
    """Run bash smoke tests for epic-autopilot."""
    result = subprocess.run(
        ["bash", "tests/e2e/epic_epic-autopilot/test_smoke.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Smoke tests failed:\n{result.stdout}\n{result.stderr}"
