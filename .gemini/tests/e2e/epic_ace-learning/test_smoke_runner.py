"""Pytest wrapper for ace-learning smoke tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

def test_smoke_ace_learning():
    """Run bash smoke tests for ace-learning."""
    result = subprocess.run(
        ["bash", "tests/e2e/epic_ace-learning/test_smoke.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Smoke tests failed:\n{result.stdout}\n{result.stderr}"
