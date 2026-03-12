"""Pytest wrapper for epic-autopilot integration tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

def test_integration_epic_autopilot():
    """Run bash integration tests for epic-autopilot."""
    result = subprocess.run(
        ["bash", "tests/integration/epic_epic-autopilot/test_integration.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=120,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Integration tests failed:\n{result.stdout}\n{result.stderr}"
