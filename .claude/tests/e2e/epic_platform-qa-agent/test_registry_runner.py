"""Pytest wrapper for platform-qa-agent registry E2E tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def test_registry_platform_qa_agent():
    """Run bash E2E tests for QA agent registry parsing."""
    result = subprocess.run(
        ["bash", "tests/e2e/epic_platform-qa-agent/test_registry.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Registry tests failed:\n{result.stdout}\n{result.stderr}"
