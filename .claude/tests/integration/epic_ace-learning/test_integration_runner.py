"""Pytest wrapper for ace-learning integration tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

def test_integration_ace_learning():
    """Run bash integration tests for ace-learning."""
    result = subprocess.run(
        ["bash", "tests/integration/epic_ace-learning/test_integration.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=120,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Integration tests failed:\n{result.stdout}\n{result.stderr}"
