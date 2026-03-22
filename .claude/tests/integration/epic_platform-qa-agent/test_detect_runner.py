"""Pytest wrapper for platform-qa-agent detection integration tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def test_detect_platform_qa_agent():
    """Run bash integration tests for QA agent detection."""
    result = subprocess.run(
        ["bash", "tests/integration/epic_platform-qa-agent/test_detect.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Detection tests failed:\n{result.stdout}\n{result.stderr}"
