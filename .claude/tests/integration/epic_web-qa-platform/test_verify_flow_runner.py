"""Pytest wrapper for web-qa-platform verify flow integration tests."""
import subprocess
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def test_verify_flow_web_qa_platform():
    """Run bash integration tests for web QA platform verify flow."""
    result = subprocess.run(
        ["bash", "tests/integration/epic_web-qa-platform/test_verify_flow.sh"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    assert result.returncode == 0, f"Verify flow tests failed:\n{result.stdout}\n{result.stderr}"
