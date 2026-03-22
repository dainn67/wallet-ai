"""Pytest runner for build-orchestrator-fidelity integration tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def test_integration_artifact_detection():
    """Verify artifact detection logic integrates correctly with build.md patterns."""
    result = subprocess.run(
        ["bash", "tests/integration/epic_build-orchestrator-fidelity/test_integration_artifact_detection.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Integration test failed:\n{result.stdout}\n{result.stderr}"
